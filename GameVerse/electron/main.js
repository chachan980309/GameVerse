const { app, BrowserWindow, Tray, Menu, nativeImage, shell, ipcMain, desktopCapturer } = require('electron');
const { autoUpdater } = require('electron-updater');
const path = require('path');
const http = require('http');
const fs = require('fs');

// ── Servidor HTTP local para servir Flutter web ────────────────────────────
let localServer;
const SERVER_PORT = 45678;

function startLocalServer() {
  const webDir = path.join(__dirname, 'web');
  const mimeTypes = {
    '.html': 'text/html',
    '.js':   'application/javascript',
    '.css':  'text/css',
    '.png':  'image/png',
    '.jpg':  'image/jpeg',
    '.svg':  'image/svg+xml',
    '.ico':  'image/x-icon',
    '.json': 'application/json',
    '.wasm': 'application/wasm',
    '.ttf':  'font/ttf',
    '.woff': 'font/woff',
    '.woff2':'font/woff2',
    '.map':  'application/json',
  };

  localServer = http.createServer((req, res) => {
    let urlPath = req.url.split('?')[0];
    if (urlPath === '/') urlPath = '/index.html';
    const filePath = path.join(webDir, urlPath);
    const ext = path.extname(filePath);
    const mime = mimeTypes[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, data) => {
      if (err) {
        // Devolver index.html para rutas no encontradas (SPA fallback)
        fs.readFile(path.join(webDir, 'index.html'), (err2, data2) => {
          if (err2) { res.writeHead(404); res.end('Not found'); return; }
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end(data2);
        });
        return;
      }
      res.writeHead(200, { 'Content-Type': mime });
      res.end(data);
    });
  });

  localServer.listen(SERVER_PORT, '127.0.0.1');
}

let mainWindow;
let tray;
let isQuitting = false;

// ── Auto-updater config ────────────────────────────────────────────────────
autoUpdater.autoDownload = true;
autoUpdater.autoInstallOnAppQuit = true;

autoUpdater.on('update-available', () => {
  mainWindow?.webContents.executeJavaScript(`
    console.log('[NUBZZZ] Nueva versión disponible, descargando...');
  `);
});

autoUpdater.on('update-downloaded', () => {
  const { dialog } = require('electron');
  dialog.showMessageBox(mainWindow, {
    type: 'info',
    title: 'Actualización lista',
    message: 'Hay una nueva versión de NUBZZZ lista para instalar.',
    buttons: ['Reiniciar ahora', 'Más tarde'],
    defaultId: 0,
  }).then(({ response }) => {
    if (response === 0) {
      isQuitting = true;
      autoUpdater.quitAndInstall();
    }
  });
});

autoUpdater.on('error', (err) => {
  console.error('[AutoUpdater] Error:', err.message);
});

// ── Crear ventana principal ────────────────────────────────────────────────
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 940,
    minHeight: 600,
    title: 'NUBZZZ',
    backgroundColor: '#08060F',
    frame: false,
    titleBarStyle: 'hidden',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      webSecurity: true,
    },
  });

  // Carga la app Flutter compilada desde el servidor local
  mainWindow.loadURL(`http://127.0.0.1:${SERVER_PORT}/`);
  
  // Habilitar screen share nativo de Windows (Windows.Graphics.Capture)
  mainWindow.webContents.session.setDisplayMediaRequestHandler((request, callback) => {
    desktopCapturer.getSources({ types: ['screen', 'window'] }).then((sources) => {
      callback({ video: sources[0], audio: 'loopback' });
    });
  }, { useSystemPicker: true }); // useSystemPicker = ventana nativa de Windows

  // Cuando el usuario cierra, minimizar al tray en vez de salir
  mainWindow.on('close', (event) => {
    if (!isQuitting) {
      event.preventDefault();
      mainWindow.hide();
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// ── Tray (ícono en la barra de tareas abajo a la derecha) ──────────────────
function createTray() {
  const iconPath = path.join(__dirname, 'assets', 'tray.png');
  const icon = nativeImage.createFromPath(iconPath);
  tray = new Tray(icon.isEmpty() ? nativeImage.createEmpty() : icon);

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Abrir NUBZZZ',
      click: () => {
        mainWindow?.show();
        mainWindow?.focus();
      },
    },
    { type: 'separator' },
    {
      label: 'Salir',
      click: () => {
        isQuitting = true;
        app.quit();
      },
    },
  ]);

  tray.setToolTip('NUBZZZ');
  tray.setContextMenu(contextMenu);

  tray.on('click', () => {
    if (mainWindow?.isVisible()) {
      mainWindow.hide();
    } else {
      mainWindow?.show();
      mainWindow?.focus();
    }
  });
}

// ── IPC: controles de ventana desde Flutter ───────────────────────────────
ipcMain.on('window-minimize', () => mainWindow?.minimize());
ipcMain.on('window-maximize', () => {
  if (mainWindow?.isMaximized()) {
    mainWindow.unmaximize();
  } else {
    mainWindow?.maximize();
  }
});
ipcMain.on('window-close', () => mainWindow?.hide());
ipcMain.on('window-quit', () => {
  isQuitting = true;
  app.quit();
});

// ── App lifecycle ──────────────────────────────────────────────────────────
app.whenReady().then(() => {
  startLocalServer();
  createWindow();
  createTray();

  // Verificar actualizaciones 5 segundos después de arrancar
  setTimeout(() => {
    autoUpdater.checkForUpdatesAndNotify();
  }, 5000);
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (!mainWindow) {
    createWindow();
  } else {
    mainWindow.show();
  }
});

app.on('before-quit', () => {
  isQuitting = true;
  localServer?.close();
});
