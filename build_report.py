#!/usr/bin/env python3
import zipfile
import os
import shutil

output_path = "/Users/akone/Documents/Projet/Entreprise/TMK/VTC Manager/Note_de_transfert_BNI_RefIdentite_V1.docx"
work_dir = "/Users/akone/Documents/Projet/Entreprise/TMK/VTC Manager/.docx_temp"

# Clean and create work directory
if os.path.exists(work_dir):
    shutil.rmtree(work_dir)
os.makedirs(f"{work_dir}/word/_rels", exist_ok=True)
os.makedirs(f"{work_dir}/_rels", exist_ok=True)

# [Content_Types].xml
with open(f"{work_dir}/[Content_Types].xml", "w") as f:
    f.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/><Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/><Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/></Types>')

# _rels/.rels
with open(f"{work_dir}/_rels/.rels", "w") as f:
    f.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')

# word/_rels/document.xml.rels
with open(f"{work_dir}/word/_rels/document.xml.rels", "w") as f:
    f.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/><Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/></Relationships>')

# styles.xml
with open(f"{work_dir}/word/styles.xml", "w") as f:
    f.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="Heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:uiPriority w:val="9"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:bCs/><w:color w:val="1A3A6B"/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="Heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:uiPriority w:val="9"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:bCs/><w:color w:val="1A3A6B"/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr></w:style></w:styles>')

# fontTable.xml
with open(f"{work_dir}/word/fontTable.xml", "w") as f:
    f.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<w:fontTable xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:font w:name="Calibri"><w:panose1 w:val="020F0502020204030203"/><w:charset w:val="00"/><w:family w:val="swiss"/><w:pitch w:val="variable"/></w:font></w:fontTable>')

# settings.xml
with open(f"{work_dir}/word/settings.xml", "w") as f:
    f.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:autoHyphenation w:val="0"/><w:defaultTabStop w:val="720"/></w:settings>')

# numbering.xml
with open(f"{work_dir}/word/numbering.xml", "w") as f:
    f.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="multilevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#x2022;"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum><w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="multilevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum><w:numDef w:numDefId="1"><w:abstractNumId w:val="0"/></w:numDef><w:numDef w:numDefId="2"><w:abstractNumId w:val="1"/></w:numDef></w:numbering>')

# document.xml - complete content
doc_content = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<w:body>
<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="100"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="40"/><w:color w:val="1A3A6B"/></w:rPr><w:t>Note de Transfert</w:t></w:r></w:p>
<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="200"/></w:pPr><w:r><w:rPr><w:sz w:val="28"/><w:color w:val="1A3A6B"/></w:rPr><w:t>BNI Référentiel d&#x2019;identité (V1)</w:t></w:r></w:p>
<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="100"/></w:pPr><w:r><w:rPr><w:i/><w:sz w:val="22"/><w:color w:val="666666"/></w:rPr><w:t>Abou KONE | Avril 2026</w:t></w:r></w:p>
<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="400"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/><w:color w:val="666666"/></w:rPr><w:t>09 Avril 2026</w:t></w:r></w:p>

<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>1. Contexte du Sprint</w:t></w:r></w:p>
<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Sprint actif: </w:t></w:r><w:r><w:t>S12 - Risk Scoring v2 (Phase 1 &#x26; 2) rattrapage</w:t></w:r></w:p>
<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Sprint précédent: </w:t></w:r><w:r><w:t>S13 - EDD, Bulk Loading, RGPD, Stabilisation</w:t></w:r></w:p>
<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Statut général: </w:t></w:r><w:r><w:t>Sur la bonne voie ✓</w:t></w:r></w:p>
<w:p><w:pPr><w:spacing w:after="200"/></w:pPr><w:r><w:t></w:t></w:r></w:p>

<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>2. Tâches en Cours (In Progress)</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>2.1 RBAC - Gestion des Rôles et Habilitations</w:t></w:r></w:p>
<w:p><w:r><w:rPr><w:i/><w:color w:val="666666"/></w:rPr><w:t>Epic #465, #471</w:t></w:r></w:p>
<w:p><w:r><w:t>Tâches RBAC en cours: #466, #467, #468, #469, #470, #496, #503, #505, #22457, #482, #485 - Toutes assignées à AK avec statut In progress ou In specification</w:t></w:r></w:p>
<w:p><w:pPr><w:spacing w:after="120"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Prochaines étapes RBAC:</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Finaliser les définitions fonctionnelles P1-P4 et P10 (matrices RBAC)</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Compléter la publication &#x26; activation des rôles (#478)</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Implémenter la gouvernance des rôles (#494)</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/><w:spacing w:after="200"/></w:numPr></w:pPr><w:r><w:t>Finaliser la traçabilité et conformité (#506, #509)</w:t></w:r></w:p>

<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>2.2 KYC - Gestion des Clients</w:t></w:r></w:p>
<w:p><w:r><w:t>Tâches KYC en cours: #222, #223, #224, #515, #516, #517 - Onboarding &#x26; Existants</w:t></w:r></w:p>
<w:p><w:pPr><w:spacing w:after="120"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Prochaines étapes KYC:</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>#226, #227 - Vérifier et faire le reKYC dans Core Banking</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>#392, #393, #395 - Gestion dynamique des pièces et Mineur Émancipé</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/><w:spacing w:after="200"/></w:numPr></w:pPr><w:r><w:t>#513, #514 - Contexte avant choix produit et détection PP/PM automatique</w:t></w:r></w:p>

<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>2.3 Re-KYC et Risk Scoring v2</w:t></w:r></w:p>
<w:p><w:r><w:t>Epic #323 - Gestion des politiques Re-KYC, mappings pays/segment/risque, cadence cycles globaux</w:t></w:r></w:p>
<w:p><w:pPr><w:spacing w:after="200"/></w:pPr><w:r><w:t>Sprint S12 - US-1.1 à US-1.4 développées, US-2.x en cours de development, US-3.x et US-RBAC en testing</w:t></w:r></w:p>

<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>3. Tests Échoués (Test Failed)</w:t></w:r></w:p>
<w:p><w:r><w:t>Ces éléments nécessitent une attention immédiate.</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>#358 - Recherche client: Saisie Nom + Prénom - Test failed - AK</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/><w:spacing w:after="120"/></w:numPr></w:pPr><w:r><w:t>#359 - Backend Search API: correspondance Nom/Prénom - Test failed - AK</w:t></w:r></w:p>
<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Action requise: </w:t></w:r><w:r><w:t>Analyser les cas de test en échec, corriger les API de recherche et relancer les tests.</w:t></w:r></w:p>
<w:p><w:pPr><w:spacing w:after="200"/></w:pPr><w:r><w:t></w:t></w:r></w:p>

<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>4. Bugs Actifs</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:rPr><w:color w:val="FF0000"/><w:b/></w:rPr><w:t>#413 - BUG KEYCLOAK</w:t></w:r><w:r><w:t> - Intégration bloquante (9 problèmes) - Confirmed - CRITIQUE - AK</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:rPr><w:color w:val="FFA500"/><w:b/></w:rPr><w:t>#656, #366, #23192, #23193, #23373</w:t></w:r><w:r><w:t> - Bugs majeurs (update prospect, import error, CBS, SoD) - In progress/In testing/New - Majeur</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/><w:spacing w:after="200"/></w:numPr></w:pPr><w:r><w:rPr><w:color w:val="4CAF50"/><w:b/></w:rPr><w:t>#23653, #23673</w:t></w:r><w:r><w:t> - Bugs mineurs (HTTP code, recherche avec espace) - New - Mineur</w:t></w:r></w:p>

<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>5. Bloqueurs</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr><w:r><w:rPr><w:b/><w:color w:val="FF0000"/></w:rPr><w:t>BUG KEYCLOAK (#413) - CRITIQUE: </w:t></w:r><w:r><w:t>L&#x2019;intégration Keycloak est bloquante. Ce bug peut bloquer l&#x2019;authentification et RBAC.</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Tests échoués recherche (#358, #359): </w:t></w:r><w:r><w:t>Bloque la validation du module de recherche client.</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Stabilisation CI/CD (#22491 - On hold): </w:t></w:r><w:r><w:t>Risque de dette technique et régressions.</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/><w:spacing w:after="200"/></w:numPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Tâche déploiement (#529): </w:t></w:r><w:r><w:t>Finalisation BNI rebond n&#x2019;a pas encore démarré.</w:t></w:r></w:p>

<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>6. Backlog Phase 2 (Post-MEP)</w:t></w:r></w:p>
<w:p><w:r><w:t>Éléments planifiés pour après mise en production:</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Parcours Personne Morale (PM): Création prospect, OTP (#387-#391)</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Gestion mappings Re-KYC (#344)</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Renouvellement mot de passe première connexion (#22502)</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Extraction OCR des pièces téléversées (#22500)</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Rôle Partenaire Agence Externe P11 - Médiasoft (#23662-#23664)</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/><w:spacing w:after="200"/></w:numPr></w:pPr><w:r><w:t>Synchronisation Référentiel Identité &#x3E; CBS (#23655-#23660)</w:t></w:r></w:p>

<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>7. Points d&#x2019;Attention pour la Passation</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Architecture hexagonale (CLAUDE.md): </w:t></w:r><w:r><w:t>Respecter 3 couches.</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Sécurité Keycloak: </w:t></w:r><w:r><w:t>Endpoints JWT-protégés. BUG #413 est critique.</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Jasypt: </w:t></w:r><w:r><w:t>Configuration sensible chiffrée. Clé au démarrage.</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Flyway: </w:t></w:r><w:r><w:t>Migrations versionnées. Ne jamais modifier existantes.</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Profils Spring: </w:t></w:r><w:r><w:t>dev, dev-docker, prod-docker.</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Coverage: </w:t></w:r><w:r><w:t>80%+ (JaCoCo).</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>GitFlow: </w:t></w:r><w:r><w:t>main, develop, feature/*, release/*, hotfix/*.</w:t></w:r></w:p>

<w:sectPr>
<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
<w:pgSz w:w="11906" w:h="16838"/>
</w:sectPr>
</w:body>
</w:document>'''

with open(f"{work_dir}/word/document.xml", "w") as f:
    f.write(doc_content)

# Create zip file
with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as docx:
    for root, dirs, files in os.walk(work_dir):
        for file in files:
            file_path = os.path.join(root, file)
            arcname = os.path.relpath(file_path, work_dir)
            docx.write(file_path, arcname)

# Clean up
shutil.rmtree(work_dir)

print("SUCCESS")
