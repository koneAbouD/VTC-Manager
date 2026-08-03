# VTC Manager — Backend

Spring Boot 3.3 / Java 21, architecture hexagonale, PostgreSQL + Flyway, Keycloak en resource server.

## Build

```bash
mvn clean package
```

Compiler avec le **JDK 21.0.8** : le 21.0.10 déclenche un bug de Lombok pendant l'annotation processing.
Il n'y a pas de wrapper `mvnw`, on utilise le `mvn` du système.

## Migrations Flyway

Les scripts vivent dans `src/main/resources/db/migration/flyway/` :

| Dossier          | Contenu                                   | Chargé par        |
|------------------|-------------------------------------------|-------------------|
| `schema/`        | DDL et migrations de structure            | dev, test, prod   |
| `jdd/reference/` | Données de référence (catégories, types…) | dev, test, prod   |
| `jdd/test/`      | Jeu de données des tests                  | test              |
| `jdd/dev/`       | Jeu de données de développement           | aucun profil (à ajouter aux `locations` du profil dev pour s'en servir) |

Les `locations` sont déclarées par profil dans `application-{dev,test,prod}.yml`.

Une migration **déjà appliquée ne se modifie jamais** (Flyway compare les checksums) : on corrige
toujours par une nouvelle migration.

### Piège : migration fantôme dans `target/classes`

Symptôme, au démarrage de l'application :

```
Found more than one migration with version 1.10.1
Offenders:
-> /…/backend/target/classes/db/migration/flyway/schema/V1.10.1__xxx.sql (SQL)
-> /…/backend/target/classes/db/migration/flyway/schema/V1.10.1__yyy.sql (SQL)
```

alors que `src/main/resources` ne contient aucun doublon. Cause : `maven-resources-plugin` ne fait
qu'ajouter et écraser, jamais supprimer. Renuméroter une migration (`V1.10.1__x.sql` →
`V1.10.2__x.sql`) laisse donc l'ancienne copie dans `target/classes`, et Flyway lit les deux.

**Le premier réflexe est de lire les deux lignes `Offenders:` du message** : si un chemin pointe dans
`target/`, c'est ce piège et non une erreur de numérotation.

Côté Maven, le problème est neutralisé : une execution `purge-migrations-obsoletes` du
`maven-clean-plugin` (voir `pom.xml`) vide `target/classes/db/migration` en phase
`generate-resources`, c'est-à-dire juste avant que les ressources ne soient recopiées. Le classpath
reflète donc toujours exactement les sources, y compris en build incrémental.

Cette garantie ne vaut que pour les builds Maven. **IntelliJ, lui, compile avec son propre
compilateur** et n'exécute pas les plugins du `pom.xml` : une migration renommée hors de l'IDE
(terminal, `git checkout`, agent) peut y laisser une copie fantôme. Deux remèdes :

- ponctuellement : *Build > Rebuild Project*, ou `mvn clean` ;
- durablement : cocher *Settings > Build, Execution, Deployment > Build Tools > Maven >
  Runner > Delegate IDE build/run actions to Maven*, ce qui fait passer les builds de l'IDE par la
  purge ci-dessus.
