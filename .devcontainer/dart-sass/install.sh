VERSION=${VERSION:-undefined}

(cd /tmp && curl https://github.com/sass/dart-sass/releases/download/${VERSION}/dart-sass-${VERSION}-linux-x64.tar.gz -fsSLO --compressed)
tar -C /opt/ -xzvf /tmp/dart-sass-${VERSION}-linux-x64.tar.gz
rm /tmp/dart-sass-${VERSION}-linux-x64.tar.gz