# ssl/

自簽憑證**不進版控**（原本誤上傳的 `server.key` / `server.crt` 已於 2026-08-18 移除）。

部署前在目標機自行產生，nginx 會掛載這個目錄：

```bash
openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
  -keyout ssl/server.key -out ssl/server.crt \
  -subj "/C=TW/ST=Taiwan/L=Taipei/O=xCloud/CN=AIR-030"
chmod 600 ssl/server.key
```

原本那組金鑰曾公開在 repo 中，任何拿到舊 `server.key` 的人都能解密以它保護的連線，
已部署的機器請一律重新簽發、不要沿用。
