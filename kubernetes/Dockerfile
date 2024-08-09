FROM node:18-slim

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install --only production

COPY . ./

RUN cp -R ASSETS _ASSETS && \
    cp -R DATAROOT _DATAROOT && \
    mv kubernetes/*.sh ./ && \
    chmod +x *.sh && \
    chown -R 1000:1000 /usr/src/app

USER 1000:1000

ENTRYPOINT ["/bin/sh", "-c"]

CMD [ "./start.sh" ]

VOLUME ["/usr/src/app/ASSETS", "/usr/src/app/DATAROOT", "/usr/src/app/LOG"]

EXPOSE 5656