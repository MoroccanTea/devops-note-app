#!/bin/bash
# Script de nettoyage de l'infrastructure

set -e

source ~/devops-aws-ids.sh

echo "=== Nettoyage de l'Infrastructure AWS DevOps ==="
echo ""
echo "⚠️  ATTENTION: Ce script va supprimer TOUTE l'infrastructure!"
echo "Cela inclut:"
echo "  - Instance EC2 et ses volumes"
echo "  - Base de données RDS"
echo "  - Application Load Balancer"
echo "  - Bucket S3 et distribution CloudFront"
echo "  - VPC et tous les composants réseau"
echo ""
read -p "Êtes-vous sûr de vouloir continuer? (tapez 'oui' pour confirmer): " CONFIRM

if [ "$CONFIRM" != "oui" ]; then
    echo "Nettoyage annulé"
    exit 0
fi

echo ""
echo "Début du nettoyage..."

# 1. Supprimer CloudFront (prend du temps)
if [ ! -z "$CLOUDFRONT_ID" ]; then
    echo "1. Désactivation de CloudFront..."
    
    # Récupérer la configuration actuelle
    aws cloudfront get-distribution-config --id $CLOUDFRONT_ID > /tmp/cf-config.json
    ETAG=$(cat /tmp/cf-config.json | jq -r '.ETag')
    
    # Modifier pour désactiver
    cat /tmp/cf-config.json | jq '.DistributionConfig.Enabled = false' | jq '.DistributionConfig' > /tmp/cf-config-disabled.json
    
    # Appliquer la modification
    aws cloudfront update-distribution \
      --id $CLOUDFRONT_ID \
      --distribution-config file:///tmp/cf-config-disabled.json \
      --if-match $ETAG
    
    echo "   CloudFront en cours de désactivation (cela prend 10-15 minutes)..."
    echo "   Suppression manuelle requise après désactivation"
fi

# 2. Vider et supprimer le bucket S3
if [ ! -z "$BUCKET_NAME" ]; then
    echo "2. Suppression du bucket S3..."
    aws s3 rm s3://$BUCKET_NAME --recursive
    aws s3 rb s3://$BUCKET_NAME
    echo "   ✓ Bucket S3 supprimé"
fi

# 3. Supprimer l'ALB
if [ ! -z "$ALB_ARN" ]; then
    echo "3. Suppression de l'Application Load Balancer..."
    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
    echo "   ✓ ALB supprimé"
fi

# 4. Supprimer le Target Group
if [ ! -z "$TG_ARN" ]; then
    echo "4. Suppression du Target Group..."
    sleep 10  # Attendre que l'ALB soit complètement supprimé
    aws elbv2 delete-target-group --target-group-arn $TG_ARN
    echo "   ✓ Target Group supprimé"
fi

# 5. Terminer l'instance EC2
if [ ! -z "$INSTANCE_ID" ]; then
    echo "5. Terminaison de l'instance EC2..."
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
    echo "   ✓ Instance EC2 terminée"
fi

# 6. Supprimer la base de données RDS
echo "6. Suppression de la base de données RDS..."
aws rds delete-db-instance \
  --db-instance-identifier devops-postgres-db \
  --skip-final-snapshot
echo "   RDS en cours de suppression (cela prend 5-10 minutes)..."

# 7. Supprimer le secret
if [ ! -z "$SECRET_ARN" ]; then
    echo "7. Suppression du secret..."
    aws secretsmanager delete-secret \
      --secret-id $SECRET_ARN \
      --force-delete-without-recovery
    echo "   ✓ Secret supprimé"
fi

# 8. Supprimer les alarmes CloudWatch
echo "8. Suppression des alarmes CloudWatch..."
aws cloudwatch delete-alarms \
  --alarm-names devops-ec2-high-cpu devops-rds-high-connections devops-alb-unhealthy-host 2>/dev/null || true
echo "   ✓ Alarmes supprimées"

# 9. Supprimer le dashboard
echo "9. Suppression du dashboard..."
aws cloudwatch delete-dashboards --dashboard-names devops-infrastructure-dashboard 2>/dev/null || true
echo "   ✓ Dashboard supprimé"

# 10. Supprimer le SNS topic
if [ ! -z "$SNS_TOPIC_ARN" ]; then
    echo "10. Suppression du SNS topic..."
    aws sns delete-topic --topic-arn $SNS_TOPIC_ARN
    echo "   ✓ SNS topic supprimé"
fi

# 11. Supprimer le NAT Gateway
if [ ! -z "$NAT_GW_ID" ]; then
    echo "11. Suppression du NAT Gateway..."
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID
    echo "   Attente de la suppression du NAT Gateway..."
    sleep 60
    echo "   ✓ NAT Gateway supprimé"
fi

# 12. Libérer l'Elastic IP
if [ ! -z "$EIP_ALLOC_ID" ]; then
    echo "12. Libération de l'Elastic IP..."
    aws ec2 release-address --allocation-id $EIP_ALLOC_ID 2>/dev/null || true
    echo "   ✓ EIP libérée"
fi

# 13. Détacher et supprimer l'Internet Gateway
if [ ! -z "$IGW_ID" ]; then
    echo "13. Suppression de l'Internet Gateway..."
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
    echo "   ✓ IGW supprimé"
fi

# 14. Supprimer les subnets
echo "14. Suppression des subnets..."
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_1 2>/dev/null || true
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_2 2>/dev/null || true
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_1 2>/dev/null || true
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_2 2>/dev/null || true
echo "   ✓ Subnets supprimés"

# 15. Supprimer les tables de routage (sauf la principale)
echo "15. Suppression des tables de routage..."
aws ec2 delete-route-table --route-table-id $PUBLIC_RT_ID 2>/dev/null || true
aws ec2 delete-route-table --route-table-id $PRIVATE_RT_ID 2>/dev/null || true
echo "   ✓ Tables de routage supprimées"

# 16. Supprimer les security groups
echo "16. Suppression des security groups..."
sleep 30  # Attendre que toutes les ressources soient détachées
aws ec2 delete-security-group --group-id $ALB_SG_ID 2>/dev/null || true
aws ec2 delete-security-group --group-id $BACKEND_SG_ID 2>/dev/null || true
aws ec2 delete-security-group --group-id $RDS_SG_ID 2>/dev/null || true
echo "   ✓ Security groups supprimés"

# 17. Supprimer le VPC
if [ ! -z "$VPC_ID" ]; then
    echo "17. Suppression du VPC..."
    aws ec2 delete-vpc --vpc-id $VPC_ID
    echo "   ✓ VPC supprimé"
fi

# 18. Supprimer les ressources IAM
echo "18. Suppression des ressources IAM..."
aws iam remove-role-from-instance-profile \
  --instance-profile-name devops-backend-profile \
  --role-name devops-backend-role 2>/dev/null || true
aws iam delete-instance-profile --instance-profile-name devops-backend-profile 2>/dev/null || true
aws iam detach-role-policy --role-name devops-backend-role --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite 2>/dev/null || true
aws iam detach-role-policy --role-name devops-backend-role --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess 2>/dev/null || true
aws iam detach-role-policy --role-name devops-backend-role --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy 2>/dev/null || true
aws iam delete-role --role-name devops-backend-role 2>/dev/null || true
echo "   ✓ Ressources IAM supprimées"

# 19. Supprimer la key pair
echo "19. Suppression de la key pair..."
aws ec2 delete-key-pair --key-name devops-keypair 2>/dev/null || true
rm -f ~/.ssh/devops-keypair.pem
echo "   ✓ Key pair supprimée"

# 20. Supprimer le DB Subnet Group
echo "20. Suppression du DB Subnet Group..."
sleep 60  # Attendre que RDS soit complètement supprimé
aws rds delete-db-subnet-group --db-subnet-group-name devops-db-subnet-group 2>/dev/null || true
echo "   ✓ DB Subnet Group supprimé"

echo ""
echo "=== Nettoyage terminé! ==="
echo ""
echo "Vérifications recommandées:"
echo "1. Vérifier dans la console EC2 qu'il ne reste pas de volumes EBS"
echo "2. Vérifier dans RDS qu'il ne reste pas de snapshots"
echo "3. Vérifier dans CloudWatch qu'il ne reste pas de log groups"
echo "4. Vérifier votre facture AWS dans quelques jours"
echo ""
echo "Le fichier ~/devops-aws-ids.sh peut être supprimé"