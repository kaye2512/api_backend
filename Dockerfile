# Dockerfile pour application NestJS
FROM node:18-alpine AS builder

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer les dépendances
RUN npm ci --only=production && npm cache clean --force

# Copier le code source
COPY . .

# Builder l'application
RUN npm run build

# Stage de production
FROM node:18-alpine AS production

# Installer dumb-init pour une gestion propre des signaux
RUN apk add --no-cache dumb-init

# Créer un utilisateur non-root
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nestjs -u 1001

# Définir le répertoire de travail
WORKDIR /app

# Copier les dépendances depuis le stage builder
COPY --from=builder --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /app/package*.json ./

# Changer vers l'utilisateur non-root
USER nestjs

# Exposer le port
EXPOSE 3000

# Définir les variables d'environnement
ENV NODE_ENV=production
ENV PORT=3000

# Point d'entrée avec dumb-init
ENTRYPOINT ["dumb-init", "--"]

# Commande par défaut
CMD ["node", "dist/main.js"]