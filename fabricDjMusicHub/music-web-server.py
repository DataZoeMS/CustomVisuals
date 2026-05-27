#!/usr/bin/env python3
"""
Music Web Server for Power BI Custom Visual
==========================================

This script creates a local HTTP server to serve your music files to the Power BI Custom Visual.
It handles CORS headers and serves files from your music directory.

Usage:
    python music-web-server.py

The server will:
1. Serve files from your music directory at http://localhost:8000
2. Add CORS headers for Power BI access
3. Handle URL encoding for spaces and special characters
4. Provide a simple status page at http://localhost:8000/status

Requirements:
    - Python 3.6+
    - Your music files organized in subdirectories
    - music-catalog-web.csv with web URLs

Author: Power BI Custom Visual Assistant
"""

import os
import sys
import threading
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import unquote
import socket
import webbrowser

class MusicCORSRequestHandler(SimpleHTTPRequestHandler):
    """Custom handler that adds CORS headers for Power BI access"""
    
    def end_headers(self):
        """Add CORS headers to all responses"""
        # Allow all origins (you can restrict this to Power BI if needed)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        # Allow range requests for audio seeking
        self.send_header('Accept-Ranges', 'bytes')
        super().end_headers()
    
    def do_OPTIONS(self):
        """Handle preflight requests"""
        self.send_response(200)
        self.end_headers()
    
    def do_GET(self):
        """Handle GET requests with special routes"""
        if self.path == '/status':
            self.send_status_page()
        elif self.path == '/test':
            self.send_test_page()
        else:
            # Decode URL-encoded paths
            self.path = unquote(self.path)
            super().do_GET()
    
    def send_status_page(self):
        """Send a status page showing server information"""
        music_dir = os.getcwd()
        
        # Count music files
        audio_extensions = {'.mp3', '.wav', '.m4a', '.flac', '.ogg'}
        music_files = []
        
        for root, dirs, files in os.walk(music_dir):
            for file in files:
                if any(file.lower().endswith(ext) for ext in audio_extensions):
                    rel_path = os.path.relpath(os.path.join(root, file), music_dir)
                    music_files.append(rel_path)
        
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Music Web Server - Status</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }}
                .container {{ background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
                .status {{ color: #28a745; font-weight: bold; }}
                .info {{ background: #e9ecef; padding: 15px; border-radius: 4px; margin: 10px 0; }}
                .file-list {{ max-height: 300px; overflow-y: auto; background: #f8f9fa; padding: 15px; border-radius: 4px; }}
                .file-item {{ margin: 5px 0; font-family: monospace; font-size: 12px; }}
                h1 {{ color: #333; }}
                h2 {{ color: #666; }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🎵 Music Web Server Status</h1>
                
                <div class="status">✅ Server is running successfully!</div>
                
                <div class="info">
                    <h2>Server Information</h2>
                    <strong>URL:</strong> http://localhost:8000<br>
                    <strong>Music Directory:</strong> {music_dir}<br>
                    <strong>Music Files Found:</strong> {len(music_files)}<br>
                    <strong>CORS Enabled:</strong> Yes (Power BI compatible)<br>
                    <strong>Audio Seeking:</strong> Supported
                </div>
                
                <div class="info">
                    <h2>Quick Test</h2>
                    <p>Try accessing: <a href="/test" target="_blank">http://localhost:8000/test</a></p>
                    <p>Sample music file URLs:</p>
                    {'<br>'.join([f'<a href="/{f.replace(os.sep, "/")}" target="_blank">/{f.replace(os.sep, "/")}</a>' for f in music_files[:5]])}
                    {f'<br><em>... and {len(music_files) - 5} more files</em>' if len(music_files) > 5 else ''}
                </div>
                
                <div class="info">
                    <h2>Power BI Integration</h2>
                    <ol>
                        <li>Import <code>music-catalog-web.csv</code> into Power BI Desktop</li>
                        <li>Use the <code>URL</code> or <code>File_Path</code> column in your Custom Visual</li>
                        <li>Map columns to data roles: Music URLs, Track Names, etc.</li>
                        <li>Test playback with DJ Mashup mode! 🎧</li>
                    </ol>
                </div>
                
                <div class="file-list">
                    <h2>Available Music Files</h2>
                    {'<br>'.join([f'<div class="file-item">{f}</div>' for f in music_files[:50]])}
                    {f'<div class="file-item"><em>... and {len(music_files) - 50} more files</em></div>' if len(music_files) > 50 else ''}
                </div>
            </div>
        </body>
        </html>
        """
        
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html_content.encode('utf-8'))
    
    def send_test_page(self):
        """Send a simple test page"""
        html_content = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Music Web Server - Test</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; text-align: center; }
                .success { color: #28a745; font-size: 24px; font-weight: bold; }
            </style>
        </head>
        <body>
            <div class="success">🎵 Music Web Server Test Successful! 🎵</div>
            <p>Your server is working correctly and ready for Power BI integration.</p>
            <p><a href="/status">← Back to Status Page</a></p>
        </body>
        </html>
        """
        
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html_content.encode('utf-8'))
    
    def log_message(self, format, *args):
        """Custom log format"""
        timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
        print(f"[{timestamp}] {format % args}")

def find_free_port(start_port=8000):
    """Find a free port starting from start_port"""
    for port in range(start_port, start_port + 100):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('localhost', port))
                return port
        except OSError:
            continue
    raise RuntimeError("No free port found")

def main():
    """Main server function"""
    print("🎵 Music Web Server for Power BI Custom Visual")
    print("=" * 50)
    
    # Check if we're in the right directory
    if not os.path.exists('music-catalog-web.csv'):
        print("⚠️  Warning: music-catalog-web.csv not found in current directory")
        print("   Make sure you're running this from the directory containing your music files")
    
    # Find available port
    try:
        port = find_free_port(8000)
    except RuntimeError:
        print("❌ Error: Could not find a free port")
        sys.exit(1)
    
    # Create server
    server_address = ('', port)
    httpd = HTTPServer(server_address, MusicCORSRequestHandler)
    
    print(f"🌐 Server URL: http://localhost:{port}")
    print(f"📁 Serving from: {os.getcwd()}")
    print(f"📊 Status page: http://localhost:{port}/status")
    print(f"🧪 Test page: http://localhost:{port}/test")
    print()
    print("🚀 Server starting...")
    print("   Press Ctrl+C to stop")
    print()
    
    # Open status page in browser after a short delay
    def open_browser():
        time.sleep(1)
        try:
            webbrowser.open(f'http://localhost:{port}/status')
        except:
            pass
    
    threading.Thread(target=open_browser, daemon=True).start()
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopping...")
        httpd.shutdown()
        print("✅ Server stopped successfully")

if __name__ == "__main__":
    main()