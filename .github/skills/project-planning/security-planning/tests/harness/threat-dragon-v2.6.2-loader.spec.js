// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Runs inside a pinned OWASP Threat Dragon v2.6.2 td.vue checkout. The pytest
// driver tests/test_threat_dragon_loader.py copies this file and the golden
// models into td.vue/tests/unit/hve-core-export/ before invoking Jest.

import fs from 'fs';
import path from 'path';
import { Model } from '@antv/x6';
import '@/service/x6/shapes';
import schema from '@/service/schema/ajv';
import threatmodelModule from '@/store/modules/threatmodel';
import { THREATMODEL_SELECTED } from '@/store/actions/threatmodel';

const fixtureDirectory = path.join(__dirname, 'fixtures');
const fixtureNames = fs.readdirSync(fixtureDirectory).filter((name) => name.endsWith('.json')).sort();

// Stroke values applied by td.vue/src/service/x6/graph/data-changed.js.
const strokeStyles = {
    default: { stroke: '#333333', strokeWidth: 1.5 },
    open: { stroke: 'red', strokeWidth: 2.5 }
};

test('golden fixtures are present', () => {
    expect(fixtureNames.length).toBeGreaterThan(0);
});

describe.each(fixtureNames)('hve-core native v2 loader: %s', (fixtureName) => {
    let model;

    beforeEach(() => {
        model = JSON.parse(fs.readFileSync(path.join(fixtureDirectory, fixtureName), 'utf8'));
    });

    test('parses as JSON with a readable title', () => {
        expect(model).toEqual(expect.any(Object));
        expect(typeof model.summary.title).toBe('string');
        expect(model.summary.title.trim().length).toBeGreaterThan(0);
    });

    test('selects native v2 without a v1, TM-BOM, or OTM migration path', () => {
        expect(schema.isV2(model)).toBe(true);
        expect(schema.isV1(model)).toBe(false);
        expect(schema.isTmBom(model)).toBe(false);
        expect(schema.isOtm(model)).toBe(false);
    });

    test('produces no upstream v2 schema errors', () => {
        expect(schema.checkV2(model)).toBeNull();
    });

    test('is accepted by THREATMODEL_SELECTED without changing the exported graph', () => {
        const selectedState = JSON.parse(JSON.stringify(threatmodelModule.state));
        const expectedDiagramCounts = model.detail.diagrams.map((diagram) => ({
            id: diagram.id,
            cellCount: diagram.cells.length
        }));
        const expectedCells = model.detail.diagrams.flatMap((diagram) => diagram.cells);
        const expectedEndpoints = expectedCells
            .filter((cell) => cell.shape === 'flow')
            .map((cell) => ({ id: cell.id, source: cell.source.cell, target: cell.target.cell }));
        const expectedThreatAttachments = expectedCells
            .filter((cell) => (cell.data.threats || []).length > 0)
            .map((cell) => ({ cellId: cell.id, threats: cell.data.threats }));

        expect(() => threatmodelModule.mutations[THREATMODEL_SELECTED](selectedState, model)).not.toThrow();

        const selected = selectedState.data;
        const selectedCells = selected.detail.diagrams.flatMap((diagram) => diagram.cells);
        expect(selected.detail.diagrams.map((diagram) => ({
            id: diagram.id,
            cellCount: diagram.cells.length
        }))).toEqual(expectedDiagramCounts);
        expect(selectedCells).toHaveLength(expectedCells.length);
        expect(selectedCells.filter((cell) => cell.shape === 'flow')
            .map((cell) => ({ id: cell.id, source: cell.source.cell, target: cell.target.cell })))
            .toEqual(expectedEndpoints);
        expect(selectedCells
            .filter((cell) => (cell.data.threats || []).length > 0)
            .map((cell) => ({ cellId: cell.id, threats: cell.data.threats })))
            .toEqual(expectedThreatAttachments);
    });

    test('draws data names and open-threat styling through Threat Dragon shapes', () => {
        model.detail.diagrams.forEach((diagram) => {
            const graphModel = new Model();
            graphModel.fromJSON({ cells: JSON.parse(JSON.stringify(diagram.cells)) });
            expect(graphModel.getCells()).toHaveLength(diagram.cells.length);

            diagram.cells.forEach((source) => {
                const cell = graphModel.getCell(source.id);
                const expected = source.data.hasOpenThreats ? strokeStyles.open : strokeStyles.default;
                expect(cell).toBeTruthy();
                expect(cell.shape).toBe(source.shape);

                if (source.shape === 'flow') {
                    expect(cell.getLabels()[0].attrs.label.text).toBe(source.data.name);
                    expect(cell.getAttrByPath('line/stroke')).toBe(expected.stroke);
                    expect(cell.getAttrByPath('line/strokeWidth')).toBe(expected.strokeWidth);
                    expect(cell.getAttrByPath('line/sourceMarker/name'))
                        .toBe(source.data.isBidirectional ? 'block' : '');
                } else if (source.shape === 'trust-boundary-box') {
                    expect(cell.getAttrByPath('label/text')).toBe(source.data.name);
                } else {
                    expect(cell.label).toBe(source.data.name);
                    const strokeTargets = source.shape === 'store' ? ['topLine', 'bottomLine'] : ['body'];
                    strokeTargets.forEach((target) => {
                        expect(cell.getAttrByPath(`${target}/stroke`)).toBe(expected.stroke);
                        expect(cell.getAttrByPath(`${target}/strokeWidth`)).toBe(expected.strokeWidth);
                    });
                }
            });
        });
    });
});
