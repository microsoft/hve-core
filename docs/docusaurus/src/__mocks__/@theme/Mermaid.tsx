import React from 'react';

export default function Mermaid({ value }: { value: string }) {
  return <pre data-testid="mermaid">{value}</pre>;
}
