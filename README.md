# cf-cdn
```
certbot certonly -d bb.111.cc --manual --preferred-challenges dns-01  --server https://acme-v02.api.letsencrypt.org/directory
```

```
sudo cp /etc/letsencrypt/live/bb.111.cc/fullchain.pem /etc/nginx/certs/bb.111.cc_cert.pem
sudo cp /etc/letsencrypt/live/bb.111.cc/privkey.pem /etc/nginx/certs/bb.111.cc_key.pem
```


```
sudo chown -R root:root /etc/nginx/certs/
sudo chmod 600 /etc/nginx/certs/*.pem
```


```
certbot certonly --nginx -d bb.111.cc
```