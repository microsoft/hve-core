const express = require('express');

const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Hello from the sample project.');
});

app.listen(port);

module.exports = app;
