<!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Portfolio</title>
  <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&family=Poppins:wght@600&display=swap" rel="stylesheet">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
      font-family: 'Roboto', sans-serif;
    }

    body {
      background: linear-gradient(135deg, #1f1c2c, #928dab);
      color: #fff;
      min-height: 100vh;
    }

    header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 20px 50px;
      background: rgba(0, 0, 0, 0.4);
      backdrop-filter: blur(5px);
    }

    header h1 {
      font-family: 'Poppins', sans-serif;
      font-size: 28px;
      color: #00fff7;
    }

    nav a {
      color: #fff;
      margin-left: 25px;
      text-decoration: none;
      font-weight: 600;
      transition: 0.3s;
    }

    nav a:hover {
      color: #00fff7;
    }

    .hero {
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      text-align: center;
      padding: 150px 20px;
      background: url('https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1600&q=80') no-repeat center/cover;
    }

    .hero h2 {
      font-size: 48px;
      color: #fff;
      text-shadow: 2px 2px 8px rgba(0, 0, 0, 0.5);
      margin-bottom: 20px;
    }

    .hero p {
      font-size: 20px;
      color: #f1f1f1;
      max-width: 600px;
      text-shadow: 1px 1px 5px rgba(0, 0, 0, 0.5);
    }

    .section {
      padding: 100px 50px;
      max-width: 1200px;
      margin: auto;
    }

    .section h3 {
      font-size: 36px;
      margin-bottom: 40px;
      text-align: center;
      color: #00fff7;
    }

    .cards {
      display: flex;
      flex-wrap: wrap;
      gap: 30px;
      justify-content: center;
    }

    .card {
      background: rgba(255, 255, 255, 0.1);
      padding: 30px;
      border-radius: 15px;
      width: 250px;
      text-align: center;
      transition: transform 0.3s, box-shadow 0.3s;
    }

    .card:hover {
      transform: translateY(-10px);
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.5);
    }

    .card h4 {
      margin-bottom: 15px;
      color: #fff;
    }

    .card p {
      color: #ddd;
      font-size: 16px;
    }

    footer {
      text-align: center;
      padding: 40px 20px;
      background: rgba(0, 0, 0, 0.4);
      backdrop-filter: blur(5px);
      color: #aaa;
    }

    @media (max-width: 768px) {
      .cards {
        flex-direction: column;
        align-items: center;
      }

      header {
        flex-direction: column;
        text-align: center;
      }

      nav {
        margin-top: 15px;
      }
    }
  </style>
</head>

<body>
  <header>
    <h1>Creative Portfolio</h1>
    <nav>
      <a href="#about">About</a>
      <a href="#skills">Skills</a>
      <a href="#contact">Contact</a>
    </nav>
  </header>

  <section class="hero">
    <h2>Hi, I'm a Web Developer</h2>
    <p>Building professional, modern, and responsive web applications that look amazing and perform smoothly across all devices.</p>
  </section>

  <section class="section" id="about">
    <h3>About Me</h3>
    <p style="text-align:center; max-width:700px; margin:auto;">Passionate about designing sleek web experiences and writing clean, maintainable code. I focus on both aesthetics and performance to create websites that users love.</p>
  </section>

  <section class="section" id="skills">
    <h3>My Skills</h3>
    <div class="cards">
      <div class="card">
        <h4>HTML & CSS</h4>
        <p>Creating clean, semantic HTML and responsive layouts with modern CSS techniques.</p>
      </div>
      <div class="card">
        <h4>JavaScript</h4>
        <p>Interactive and dynamic web experiences using vanilla JS or frameworks like React.</p>
      </div>
      <div class="card">
        <h4>Backend</h4>
        <p>Node.js & Express APIs, connecting front-end with databases efficiently.</p>
      </div>
      <div class="card">
        <h4>DevOps & CI/CD</h4>
        <p>Automated pipelines and deployment strategies for fast and reliable delivery.</p>
      </div>
    </div>
  </section>

  <section class="section" id="contact">
    <h3>Contact Me</h3>
    <form style="max-width:500px; margin:auto; display:flex; flex-direction:column; gap:15px;">
      <input type="text" placeholder="Name" required style="padding:10px; border-radius:8px; border:none;">
      <input type="email" placeholder="Email" required style="padding:10px; border-radius:8px; border:none;">
      <textarea placeholder="Message" rows="5" required style="padding:10px; border-radius:8px; border:none;"></textarea>
      <button type="submit" style="padding:12px; border-radius:8px; border:none; background:#00fff7; color:#000; font-weight:bold; cursor:pointer; transition:0.3s;">Send Message</button>
    </form>
  </section>

  <footer>
    &copy; 2026 | Modern Portfolio Design
  </footer>
</body>

</html>
