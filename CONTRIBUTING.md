# Contributing to Mailserver K8s

Merci de votre intérêt pour contribuer à ce projet ! 🎉

## 📋 Table des matières

- [Code de Conduite](#code-de-conduite)
- [Comment contribuer](#comment-contribuer)
- [Workflow de développement](#workflow-de-développement)
- [Standards de code](#standards-de-code)
- [Commits et messages](#commits-et-messages)
- [Pull Requests](#pull-requests)
- [Tests](#tests)

## Code de Conduite

Ce projet adhère au code de conduite [Contributor Covenant](https://www.contributor-covenant.org/). En participant, vous êtes tenu de respecter ce code.

## Comment contribuer

### Signaler des bugs

Utilisez les GitHub Issues en incluant :
- Description claire du problème
- Étapes pour reproduire
- Comportement attendu vs observé
- Version de Kubernetes, Helm, et du projet
- Logs pertinents

### Proposer des fonctionnalités

1. Vérifiez que la fonctionnalité n'est pas déjà en discussion
2. Créez une issue avec le label `enhancement`
3. Décrivez le cas d'usage et la valeur ajoutée
4. Attendez les retours avant de commencer l'implémentation

### Améliorer la documentation

Les améliorations de documentation sont toujours bienvenues ! Elles ne nécessitent pas d'issue préalable.

## Workflow de développement

### 1. Fork et Clone

```bash
# Fork le repo sur GitHub, puis :
git clone https://github.com/votre-username/mailserver-k8s.git
cd mailserver-k8s
git remote add upstream https://github.com/org-originale/mailserver-k8s.git
```

### 2. Créer une branche

```bash
git checkout -b feature/ma-nouvelle-fonctionnalite
# ou
git checkout -b fix/correction-bug-xyz
```

### 3. Développer

- Suivez les [standards de code](#standards-de-code)
- Écrivez des tests
- Testez localement
- Committez régulièrement avec des messages clairs

### 4. Synchroniser avec upstream

```bash
git fetch upstream
git rebase upstream/main
```

### 5. Push et Pull Request

```bash
git push origin feature/ma-nouvelle-fonctionnalite
```

Créez ensuite une Pull Request sur GitHub.

## Standards de code

### Structure des commits

Nous utilisons une approche commit-par-fonctionnalité :

```
type(scope): Description courte

Description détaillée si nécessaire.

Fixes #123
```

**Types** :
- `feat`: Nouvelle fonctionnalité
- `fix`: Correction de bug
- `docs`: Documentation
- `style`: Formatage, pas de changement de code
- `refactor`: Refactoring sans changement fonctionnel
- `test`: Ajout/modification de tests
- `chore`: Tâches de maintenance

**Scopes** :
- `postfix`, `dovecot`, `rspamd`, `api`, `ui`, `helm`, `ci`, `docs`

**Exemples** :
```
feat(postfix): Add DKIM signing support
fix(api): Resolve user creation validation error
docs(helm): Update values.yaml documentation
```

### Code Style

#### Python
- PEP 8
- Type hints obligatoires
- Docstrings pour fonctions publiques
- Maximum 88 caractères par ligne (Black formatter)

```python
def create_user(username: str, domain: str, password: str) -> dict:
    """Create a new email user.
    
    Args:
        username: The username part of the email
        domain: The domain part of the email
        password: The user's password
        
    Returns:
        dict: User information including ID and creation timestamp
    """
    pass
```

#### JavaScript/React
- ESLint avec config Airbnb
- Prettier pour le formatage
- Composants fonctionnels avec hooks
- PropTypes obligatoires

```javascript
const UserList = ({ users, onUserSelect }) => {
  // Component implementation
};

UserList.propTypes = {
  users: PropTypes.array.isRequired,
  onUserSelect: PropTypes.func.isRequired
};
```

#### Bash
- shellcheck validation
- Set `-euo pipefail`
- Commentaires pour logique complexe

```bash
#!/bin/bash
set -euo pipefail

# Description du script
# Usage: ./script.sh <arg>

main() {
    local arg="${1:-default}"
    # Implementation
}

main "$@"
```

#### YAML (Kubernetes/Helm)
- 2 espaces d'indentation
- Pas de tabs
- yamllint validation

### Dockerfiles
- Multi-stage builds préférés
- Images de base minimales (Alpine où possible)
- Non-root user
- Labels appropriés
- .dockerignore présent

```dockerfile
FROM alpine:3.19 AS builder
RUN apk add --no-cache build-essential

FROM alpine:3.19
LABEL maintainer="team@example.com"
LABEL version="1.0"

RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

USER appuser
WORKDIR /app

COPY --from=builder /build/output .
CMD ["./app"]
```

## Commits et messages

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Règles
- Subject en minuscule, impératif présent
- Pas de point final dans le subject
- Maximum 72 caractères pour le subject
- Body optionnel pour expliquer le "pourquoi"
- Footer pour références (Closes #123, Refs #456)

### Exemples

✅ **Bon** :
```
feat(dovecot): add quota warning notification

Implement email notifications when users reach 80% and 95%
of their mailbox quota. Notifications are templated and
configurable via values.yaml.

Closes #45
```

❌ **Mauvais** :
```
Updated some files
```

## Pull Requests

### Checklist avant PR

- [ ] Tests passent localement
- [ ] Code lint sans erreurs
- [ ] Documentation mise à jour
- [ ] CHANGELOG.md mis à jour (si applicable)
- [ ] Commit messages respectent les conventions
- [ ] Pas de secrets/credentials dans le code

### Template PR

```markdown
## Description
Brève description des changements

## Type de changement
- [ ] Bug fix
- [ ] Nouvelle fonctionnalité
- [ ] Breaking change
- [ ] Documentation

## Tests effectués
Description des tests réalisés

## Checklist
- [ ] Mon code suit les standards du projet
- [ ] J'ai commenté les parties complexes
- [ ] J'ai mis à jour la documentation
- [ ] Mes changements ne génèrent pas de nouveaux warnings
- [ ] J'ai ajouté des tests qui prouvent mon fix/fonctionnalité
- [ ] Les tests unitaires et d'intégration passent
```

### Review process

1. Au moins un reviewer requis
2. CI doit passer (build, tests, lint)
3. Résolution des commentaires
4. Squash merge préféré pour garder l'historique propre

## Tests

### Tests requis

```bash
# Linting
make lint

# Tests unitaires
make test-unit

# Tests d'intégration (nécessite Docker)
make test-integration

# Tests e2e (nécessite K8s)
make test-e2e

# Security scan
make security-scan
```

### Couverture de code

- Minimum 80% de couverture pour nouveau code
- Vérifier avec `make coverage`

### Tests locaux Kubernetes

```bash
# Utiliser kind pour tester localement
kind create cluster --name mailserver-test
helm install mailserver ./infra/helm/mailserver -f test-values.yaml
./scripts/testing/smoke-test.sh
kind delete cluster --name mailserver-test
```

## Questions ?

N'hésitez pas à :
- Ouvrir une issue avec le label `question`
- Rejoindre les discussions GitHub
- Contacter les mainteneurs

Merci de contribuer ! 🚀