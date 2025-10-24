#!/bin/bash
# Script de déploiement du frontend

set -e

# Charger les variables
source ~/devops-aws-ids.sh

echo "=== Déploiement du Frontend DevOps Todo App ==="
echo ""

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "app/frontend/index.html" ]; then
    echo "Erreur: Exécutez ce script depuis la racine du projet"
    exit 1
fi

# Aller dans le répertoire frontend
cd app/frontend

# Vérifier la configuration
echo "1. Vérification de la configuration..."
if grep -q "YOUR_ALB_DNS_HERE" config.js; then
    echo "Configuration de l'URL de l'API..."
    sed -i "s|YOUR_ALB_DNS_HERE|${ALB_DNS}|g" config.js
fi

echo "Configuration actuelle:"
grep "baseURL" config.js

# Upload vers S3
echo ""
echo "2. Upload vers S3..."
aws s3 sync . s3://$BUCKET_NAME \
  --exclude ".git/*" \
  --exclude "*.md" \
  --delete

# Invalider le cache CloudFront
if [ ! -z "$CLOUDFRONT_ID" ]; then
    echo ""
    echo "3. Invalidation du cache CloudFront..."
    aws cloudfront create-invalidation \
      --distribution-id $CLOUDFRONT_ID \
      --paths "/*"
fi

echo ""
echo "✓ Déploiement terminé!"
echo "URL S3: http://${BUCKET_NAME}.s3-website-eu-west-1.amazonaws.com"
if [ ! -z "$CLOUDFRONT_DOMAIN" ]; then
    echo "URL CloudFront: https://${CLOUDFRONT_DOMAIN}"
fi