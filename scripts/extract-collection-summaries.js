const fs = require('fs');
const path = require('path');

const collectionsDir = path.join(__dirname, '../collections');
const outputFile = path.join(__dirname, '../docs/docusaurus/src/components/CollectionsTable/collectionData.json');

const files = fs.readdirSync(collectionsDir).filter(f => f.endsWith('.collection.md'));

const result = [];

files.forEach(file => {
  const content = fs.readFileSync(path.join(collectionsDir, file), 'utf8');
  const lines = content.split('\n');
  
  // Find first non-empty line that isn't a frontmatter dash, comment, heading, or blockquote
  let summary = '';
  for (let line of lines) {
    line = line.trim();
    if (line && !line.startsWith('---') && !line.startsWith('>') && !line.startsWith('#') && !line.startsWith('<!--')) {
      summary = line;
      break;
    }
  }

  const name = file.replace('.collection.md', '');
  
  result.push({
    name,
    summary,
  });
});

fs.writeFileSync(outputFile, JSON.stringify(result, null, 2));
console.log(`Extracted summaries to ${outputFile}`);
