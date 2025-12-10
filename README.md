# 📬 Mailserver Kubernetes - Production-Ready Email Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Multi-Arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-blue)](https://github.com/)
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.25%2B-blue)](https://kubernetes.io/)

Une solution complète de messagerie professionnelle hautement disponible, sécurisée et scalable, déployable sur Kubernetes.

## 🎯 Objectifs

- **Production-Ready** : Haute disponibilité, monitoring, backups automatiques
- **Sécurité** : TLS, DKIM, DMARC, SPF, antispam, antivirus
- **Multi-architecture** : Support amd64 et arm64
- **Cloud-Native** : Déployable sur tout cluster Kubernetes via Helm
- **Observabilité** : Métriques Prometheus, dashboards Grafana, logs centralisés

## ✨ Fonctionnalités

### Serveur Mail
- **MTA** : Postfix (SMTP entrant/sortant)
- **MDA** : Dovecot (IMAP, POP3, LMTP)
- **Stockage** : Maildir avec quotas par utilisateur
- **Authentification** : SASL via Dovecot, base MySQL/MariaDB

### Sécurité & Délivrabilité
- **TLS** : Certificats automatiques via cert-manager (Let's Encrypt)
- **DKIM** : Signature automatique des emails sortants
- **SPF & DMARC** : Configuration et reporting
- **Antispam** : Rspamd avec scoring avancé
- **Antivirus** : ClamAV pour scan des pièces jointes
- **Rate Limiting** : Protection contre les abus

### Interface Web
- **Admin Console** : Gestion utilisateurs, domaines, quotas, statistiques
- **Webmail** : Interface moderne pour les utilisateurs finaux
- **Collaboration** : Calendriers (CalDAV), Contacts (CardDAV)
- **Filtres** : Gestion des règles Sieve par l'utilisateur

### Haute Disponibilité
- **Scalabilité horizontale** : Postfix et Dovecot en cluster
- **Réplication** : Synchronisation des boîtes mail (dsync)
- **Multi-tenant** : Support de domaines multiples
- **Backups** : Sauvegardes incrémentales vers S3

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet / Users                         │
└──────────────────┬──────────────────────────────────────────┘
                   │
         ┌─────────▼─────────┐
         │  Ingress / LB     │
         │  (TLS Termination)│
         └─────────┬─────────┘
                   │
      ┌────────────┼────────────┐
      │            │            │
┌─────▼─────┐ ┌───▼────┐ ┌────▼─────┐
│  Postfix  │ │Web UI  │ │ Admin API│
│  (SMTP)   │ │(React) │ │(REST API)│
└─────┬─────┘ └───┬────┘ └────┬─────┘
      │           │            │
      │      ┌────▼────────────▼─────┐
      │      │   MySQL / MariaDB     │
      │      │  (Users, Domains)     │
      │      └───────────────────────┘
      │
┌─────▼─────────────────┐
│  Rspamd + ClamAV      │
│  (Spam/Virus Filter)  │
└─────┬─────────────────┘
      │
┌─────▼──────┐
│  OpenDKIM  │
│  (Signing) │
└─────┬──────┘
      │
┌─────▼─────┐
│  Dovecot  │
│  (IMAP)   │
└─────┬─────┘
      │
┌─────▼─────┐
│  Storage  │
│  (PVC)    │
└───────────┘
```

## 📋 Prérequis

- **Kubernetes** : v1.25+ (recommandé v1.28+)
- **Helm** : v3.10+
- **kubectl** : Compatible avec votre version K8s
- **Cert-manager** : v1.12+ (pour TLS automatique)
- **Storage Class** : Pour les volumes persistants
- **Load Balancer** : Pour exposition SMTP/IMAP (ou NodePort en dev)

### Optionnel
- **Prometheus** : Pour les métriques
- **Grafana** : Pour les dashboards
- **MinIO / S3** : Pour les backups

## 🚀 Installation Rapide

```bash
# 1. Cloner le repository
git clone https://github.com/votre-org/mailserver-k8s.git
cd mailserver-k8s

# 2. Configurer les valeurs
cp infra/helm/mailserver/values.yaml my-values.yaml
# Éditer my-values.yaml avec vos paramètres

# 3. Déployer via Helm
helm install mailserver ./infra/helm/mailserver \
  -f my-values.yaml \
  --namespace mail \
  --create-namespace

# 4. Vérifier le déploiement
kubectl get pods -n mail
kubectl get svc -n mail
```

## 📖 Documentation

- [Installation Complète](docs/INSTALL.md)
- [Guide d'Opération](docs/OPERATIONS.md)
- [Migration depuis Exchange](docs/MIGRATION_FROM_EXCHANGE.md)
- [Architecture Détaillée](docs/architecture/README.md)
- [API Documentation](docs/API.md)

## 🔧 Développement

### Build Local

```bash
# Build des images multi-arch
docker buildx build --platform linux/amd64,linux/arm64 \
  -t mailserver/postfix:latest \
  ./services/postfix

# Tests
make test

# Linting
make lint
```

### CI/CD

Le projet utilise GitHub Actions pour :
- Build multi-architecture des images
- Tests automatisés (unit, integration, e2e)
- Scan de sécurité (Trivy)
- Publication des images et charts Helm

## 🧪 Tests

```bash
# Tests unitaires
make test-unit

# Tests d'intégration
make test-integration

# Tests end-to-end (nécessite un cluster K8s)
make test-e2e

# Test d'envoi/réception
./scripts/testing/smoke-test.sh
```

## 📊 Monitoring

Dashboards Grafana inclus :
- **Mail Server Overview** : Métriques globales
- **Queue Depth** : Profondeur de la queue Postfix
- **IMAP Performance** : Latence et connexions Dovecot
- **Spam Detection** : Statistiques Rspamd
- **Deliverability** : DKIM/SPF/DMARC status

## 💾 Backup & Restore

```bash
# Backup complet
./scripts/backup/full-backup.sh

# Restore d'une boîte utilisateur
./scripts/restore/restore-mailbox.sh user@domain.com

# Restore d'un domaine
./scripts/restore/restore-domain.sh domain.com
```

## 🤝 Contribution

Les contributions sont les bienvenues ! Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour les guidelines.

## 📄 License

MIT License - voir [LICENSE](LICENSE) pour les détails.

## 🙏 Remerciements

Basé sur les excellents projets open-source :
- [Postfix](http://www.postfix.org/)
- [Dovecot](https://www.dovecot.org/)
- [Rspamd](https://rspamd.com/)
- [ClamAV](https://www.clamav.net/)

## 📞 Support

- **Issues** : GitHub Issues
- **Discussions** : GitHub Discussions
- **Email** : support@votredomaine.com

---

**Version** : 0.1.0 | **Status** : 🚧 En développement actif