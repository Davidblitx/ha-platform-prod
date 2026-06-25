#!/bin/bash
set -e
set -o pipefail

# 1. Update package index
sudo apt update 

# 2. Install Docker
sudo apt install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings 
sudo curl -fSSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker-sources.list << 'EOF'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: \$(. /etc/os-release && echo "\${UBUNTU_CODENAME:-\$VERSION_CODENAME}")
Components: stable
Architectures: \$(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# 3. Start and enable Docker service
sudo systemctl start docker

sudo systemctl enable docker

# 4. Create app directory
sudo mkdir -p /opt/app/

# 5. Write app.py (heredoc)
cat > /opt/app/app.py << 'EOF'
from flask import Flask
app = flask(__name__)

@app.route("/")
def hello_world():
    return "Hello world from platform prod"
EOF

# 6. Write requirements.txt (heredoc)
cat > /opt/app/requirements.txt << 'EOF'
blinker==1.9.0
click==8.4.1
Flask==3.1.3
gunicorn==26.0.0
itsdangerous==2.2.0
Jinja2==3.1.6
MarkupSafe==3.0.3
packaging==26.2
Werkzeug==3.1.8
EOF

# 7. Write Dockerfile (heredoc)
cat > /opt/app/Dockerfile << 'EOF'
FROM pythin:3.11-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "app:app"]
EOF

# 8. Build Docker image
docker build -t ha-platform-app /opt/app/

# 9. Run Docker container
docker run -d --name ha-platform-app --restart unless-stopped -p 8000:8000 ha-platform-app

# 10. Install Nginx
sudo apt install nginx -y

# 11. Write Nginx config (heredoc)
cat > /etc/nginx/sites-available/ha-platform << 'EOF'
server {
    listen 80;

    location / {
        proxy_pass http://127.0.0.1:8000;
    }
}
EOF

# 12. Remove default site symlink
sudo rm /etc/nginx/sites-enabled/default

# 13. Create ha-platform symlink
sudo ln -s /etc/nginx/sites-available/ha-platform /etc/nginx/sites-enabled/

# 14. Test and reload Nginx
sudo nginx -t

sudo systemctl reload nginx



