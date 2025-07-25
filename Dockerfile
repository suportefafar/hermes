FROM node:18

WORKDIR /usr/app

USER root

COPY --chown=node:node package*.json ./
COPY --chown=node:node prisma ./prisma/

# Install app dependencies
RUN npm install

COPY --chown=node:node . .

USER node

EXPOSE 4650
CMD ["node","/usr/app/src/index.js"]