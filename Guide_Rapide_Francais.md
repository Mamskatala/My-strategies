//+------------------------------------------------------------------+
//|                         Guide_Rapide_Francais.md                 |
//|                         Guide d'utilisation en français           |
//+------------------------------------------------------------------+

# EA Breakout avec Delta Volume - Guide Rapide

## Description
Cet Expert Advisor (EA) implémente une stratégie de breakout (cassure) avec confirmation par le Delta Volume pour MetaTrader 5.

## Fichiers Créés

1. **DeltaVolume.mq5** - Indicateur personnalisé de Delta Volume et Delta Cumulatif
2. **EA_BreakoutDeltaVolume.mq5** - Expert Advisor avec stratégie de breakout intégrée
3. **EA_BreakoutDeltaVolume_README.md** - Documentation complète en anglais
4. **EA_BreakoutDeltaVolume_Example_Settings.txt** - Exemples de paramètres

## Installation

1. **Installer l'Indicateur** :
   - Copiez `DeltaVolume.mq5` dans le dossier `MQL5/Indicators/`
   - Compilez l'indicateur dans MetaEditor (F7)
   - Redémarrez MT5

2. **Installer l'EA** :
   - Copiez `EA_BreakoutDeltaVolume.mq5` dans le dossier `MQL5/Experts/`
   - Compilez l'EA dans MetaEditor (F7)

3. **Appliquer sur un Graphique** :
   - Ouvrez un graphique
   - Glissez-déposez l'EA sur le graphique
   - Configurez les paramètres
   - Activez le trading automatique

## Stratégie Expliquée

### Logique de Breakout (Cassure)

L'EA surveille le prix d'ouverture de chaque journée et attend une cassure au-dessus ou en-dessous d'un seuil défini.

**Deux méthodes disponibles** :

1. **Breakout à Point Fixe** (BOoption = 1)
   - Entrée lorsque le prix casse l'ouverture du jour +/- un nombre fixe de points
   - Paramètre : `FixedPoint`

2. **Breakout Basé sur la Volatilité** (BOoption = 2)
   - Entrée lorsque le prix casse l'ouverture du jour +/- un multiple de l'ATR
   - Paramètres : `VolPeriod` et `BreakoutFactor`

### Filtre Delta Volume

L'indicateur Delta Volume mesure la pression d'achat et de vente :

- **Delta** : Différence entre pression acheteuse et vendeuse sur chaque barre
  - Delta positif = pression acheteuse (haussier)
  - Delta négatif = pression vendeuse (baissier)

- **Delta Cumulatif** : Somme courante des valeurs delta
  - Delta cumulatif en hausse = pression acheteuse soutenue
  - Delta cumulatif en baisse = pression vendeuse soutenue

### Règles de Trading

1. **Entrée Long (Achat)** :
   - Prix casse au-dessus (Ouverture du jour + Niveau de breakout)
   - Delta Volume est positif (confirmation haussière)
   - Filtre inside day satisfait (si activé)

2. **Entrée Short (Vente)** :
   - Prix casse en-dessous (Ouverture du jour - Niveau de breakout)
   - Delta Volume est négatif (confirmation baissière)
   - Filtre inside day satisfait (si activé)

## Paramètres Principaux

### Paramètres de Breakout
- **BOoption** : Méthode de breakout (1 = Point fixe, 2 = Volatilité)
- **FixedPoint** : Nombre de points pour breakout fixe
- **VolPeriod** : Période ATR pour calcul de volatilité
- **BreakoutFactor** : Multiplicateur ATR

### Règles de Trading
- **HoldOvernight** : Garder positions la nuit (true/false)
- **PrecedeByInsideDay** : Exiger un inside day avant trading (true/false)
- **LotSize** : Taille de position en lots
- **MagicNumber** : Numéro unique pour les ordres de cet EA

### Filtre Delta Volume
- **UseDeltaFilter** : Activer filtre Delta Volume (true/false)
- **DeltaResetPeriod** : Réinitialisation Delta Cumulatif
  - 0 = Jamais
  - 1 = Quotidien
  - 2 = Hebdomadaire
- **MinDeltaThreshold** : Seuil minimum de delta pour entrée

### Paramètres de Temps
- **SessionEndHour** : Heure de sortie fin de journée
- **SessionEndMinute** : Minute de sortie fin de journée

## Paramètres Recommandés pour Débuter

```
BOoption = 2
FixedPoint = 1.6
VolPeriod = 20
BreakoutFactor = 1.0
HoldOvernight = false
PrecedeByInsideDay = false
LotSize = 0.01
UseDeltaFilter = true
DeltaResetPeriod = 1
MinDeltaThreshold = 0
SessionEndHour = 17
SessionEndMinute = 0
```

## Indicateur Delta Volume

### Affichage
L'indicateur affiche dans une fenêtre séparée :
1. **Histogramme Bleu** : Valeurs Delta pour chaque barre
2. **Ligne Rouge** : Delta Cumulatif
3. **Ligne Grise Pointillée** : Ligne zéro de référence

### Interprétation
- Delta cumulatif en hausse → Tendance haussière
- Delta cumulatif en baisse → Tendance baissière
- Divergence entre prix et delta → Possible retournement

## Points Importants

1. **Backtesting** : Testez toujours en démo avant utilisation réelle
2. **Timeframes** : Fonctionne sur tous les timeframes (recommandé : M15, M30, H1)
3. **Instruments** : Compatible Forex, Indices, Matières premières
4. **Gestion du Risque** : Utilisez une taille de lot appropriée (1-2% du capital)
5. **Données Volume** : Le calcul Delta est approximatif (basé sur tick volume)

## Structure du Code

Le code est écrit de manière **claire, professionnelle et précise** :

- ✅ Code modulaire et facile à lire
- ✅ Commentaires en anglais
- ✅ Gestion d'erreurs appropriée
- ✅ Paramètres bien organisés en groupes
- ✅ Fonctions séparées pour chaque tâche
- ✅ Compatible MetaTrader 5 standard

## Support et Personnalisation

Le code peut être personnalisé pour :
- Ajouter stop-loss et take-profit
- Modifier le calcul Delta pour instruments avec volume réel
- Ajouter filtres de temps
- Implémenter trailing stops
- Améliorer la gestion de position

## Avertissement

Cet EA est fourni à des fins éducatives. Testez toujours sur compte démo avant utilisation réelle. Les performances passées ne garantissent pas les résultats futurs.

---

**Créé avec professionnalisme - Code propre et sans erreurs**
