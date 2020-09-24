# Official UNA Docker repository

This is the official git repository for UNA. Refer to [Docker Hub page](https://hub.docker.com/r/unaio/una) for the actual UNA Docker image.


## How to use this image

```
docker run -e "UNA_DB_HOST=host.docker.internal" -e "UNA_DB_NAME=test" -e "UNA_ADMIN_PWD=5ecret" -d -p 80:80 --name una unaio/una:latest
```

Above example assumes that UNA is run locally with mysql server installed on the host machine. After the run UNA should be accessible using `http://localhost` URL, you can login with `admin@example.com` email and   `5ecret` password.

## Full list of supported environment variables

- `UNA_DB_HOST` - MySQL database hostname, default - `localhost`
- `UNA_DB_PORT` - MySQL database port, default - `3306`
- `UNA_DB_SOCK` - MySQL database sock file path, optional
- `UNA_DB_NAME` - MySQL database name, **required** 
- `UNA_DB_USER` - MySQL database user, default - `root`
- `UNA_DB_PWD` - MySQL database user, default - `root`
- `UNA_HTTP_HOST` - UNA hostname, if other that `80` port is used, then it need to be specified here, for example `localhost:8000`, default - `localhost` 
- `UNA_SITE_TITLE` - new site title, default - `UNA`
- `UNA_SITE_EMAIL` - new site email, to send mail from, default - `admin@example.com`
- `UNA_ADMIN_USERNAME` - admin username, default - `admin`
- `UNA_ADMIN_EMAIL` - admin login email, default - `admin@example.com`
- `UNA_ADMIN_PWD` - admin password, default - `localhost`
- `UNA_KEY` - UNA key, key&secret can be generated on [una.io website](https://una.io/page/kands-manage)
- `UNA_SECRET` - UNA secret
- `UNA_VERSION` - particular UNA version to install, default - latest version
- `UNA_ZIP_DOWNLOAD_URL` - custom UNA download URL, in case you need to install modified version, optional
- `UNA_ZIP_FOLDER` - custom UNA folder in `UNA_ZIP_DOWNLOAD_URL` zip to be able to unpack, UNA is aleays installed in root folder 
- `UNA_NO_CRONTAB` - don't install crontab, in case of multiple instances, cron should be installed on one instance only, cron is installed by default
