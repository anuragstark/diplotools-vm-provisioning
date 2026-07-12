const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

// The main route showing the requested message
app.get('/', (req, res) => {
  const serviceName = process.env.SERVICE_NAME || 'Backend';
  // res.send(`<h1>I'm Iron-man </h1><p>Served by: ${serviceName}</p>`);
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Iron-man Platform</title>
      <style>
        @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;500;700&display=swap');
        
        body {
          margin: 0;
          padding: 0;
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          font-family: 'Outfit', sans-serif;
          background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 100%);
          color: #ffffff;
        }

        .container {
          background: rgba(255, 255, 255, 0.05);
          backdrop-filter: blur(10px);
          -webkit-backdrop-filter: blur(10px);
          border: 1px solid rgba(255, 255, 255, 0.1);
          border-radius: 24px;
          padding: 3rem 4rem;
          text-align: center;
          box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
          animation: float 6s ease-in-out infinite;
        }

        h1 {
          font-size: 3.5rem;
          margin: 0 0 1rem 0;
          background: linear-gradient(to right, #60a5fa, #c084fc);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
          font-weight: 700;
        }

        .badge {
          display: inline-block;
          background: rgba(96, 165, 250, 0.1);
          color: #93c5fd;
          padding: 0.5rem 1.5rem;
          border-radius: 9999px;
          font-size: 1.1rem;
          font-weight: 500;
          border: 1px solid rgba(96, 165, 250, 0.2);
          margin-top: 1rem;
        }

        @keyframes float {
          0% { transform: translateY(0px); }
          50% { transform: translateY(-10px); }
          100% { transform: translateY(0px); }
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>I'm Iron-Man ⛛ <br><span style="font-size: 0.5em; color: #ffeb3b;">(Dev Environment - New Feature Coming soon!)</span></h1>
        <div class="badge">Served by: ${serviceName}</div>
      </div>
    </body>
    </html>
  `);
});

// Health check endpoint 
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// Liveness endpoint
app.get('/live', (req, res) => {
  res.status(200).send('Alive');
});

app.listen(port, () => {
  console.log(`Iron-man app listening on port ${port}`);
});
