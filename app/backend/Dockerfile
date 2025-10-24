# Stage 1: Build
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Installer les dépendances de build
RUN apk add --no-cache git

# Copier les fichiers go.mod et go.sum
COPY go.mod go.sum ./
RUN go mod download

# Copier le code source
COPY . .

# Builder l'application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o api .

# Stage 2: Runtime
FROM alpine:latest

# Installer ca-certificates pour HTTPS et aws-cli pour récupérer les secrets
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /root/

# Copier le binaire depuis le stage de build
COPY --from=builder /build/api .

# Exposer le port
EXPOSE 8080

# Variables d'environnement par défaut
ENV PORT=8080
ENV DB_CREDENTIALS_FILE=/app/db-credentials.json

# Créer le répertoire pour les logs
RUN mkdir -p /app/logs

# Commande de démarrage
CMD ["./api"]