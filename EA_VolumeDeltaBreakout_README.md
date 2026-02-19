# EA Volume Delta Breakout - Documentation

## Vue d'ensemble

**EA_VolumeDeltaBreakout.mq5** est un Expert Advisor (EA) pour MetaTrader 5 qui implémente une stratégie de breakout (cassure) avec confirmation par l'indicateur Volume Delta. Cette EA est basée sur le code fourni et intègre un filtre de volume pour améliorer la qualité des signaux de trading.

## Fonctionnalités principales

### 1. Stratégie de Breakout

L'EA utilise deux méthodes pour calculer le niveau de breakout :

#### Option 1 : Fixed Point (Point Fixe)
- Utilise un nombre fixe de points pour définir le niveau de breakout
- Paramètre : `FixedPoint` (par défaut : 1.6)
- Niveau d'achat : Prix d'ouverture + FixedPoint
- Niveau de vente : Prix d'ouverture - FixedPoint

#### Option 2 : Volatility-Based (Basé sur la Volatilité)
- Utilise l'indicateur ATR (Average True Range) pour calculer le niveau de breakout
- Paramètres :
  - `VolPer` : Période de l'ATR (par défaut : 20)
  - `BreakoutFactor` : Multiplicateur de volatilité (par défaut : 1.0)
- Niveau de breakout = ATR × BreakoutFactor

### 2. Indicateur Volume Delta

L'indicateur Volume Delta mesure la différence entre le volume d'achat et de vente :

- **Volume Delta positif** : Pression acheteuse (bullish)
- **Volume Delta négatif** : Pression vendeuse (bearish)

#### Calcul du Volume Delta
Pour chaque bougie sur la période définie (`VDPeriod`) :
- Si Close > Open : Volume ajouté (achat)
- Si Close < Open : Volume soustrait (vente)
- Si Close = Open : Volume neutre (ignoré)

Le Volume Delta cumulatif est ensuite normalisé sur la période.

### 3. Confirmation des Trades

Les trades ne sont exécutés que si **DEUX conditions** sont remplies :

#### Signal d'achat (Long)
1. Le prix casse au-dessus de `Prix d'ouverture + Breakout Level`
2. Volume Delta ≥ `VDThreshold` (confirmation de pression acheteuse)

#### Signal de vente (Short)
1. Le prix casse en-dessous de `Prix d'ouverture - Breakout Level`
2. Volume Delta ≤ `-VDThreshold` (confirmation de pression vendeuse)

### 4. Gestion des Positions

#### Inside Day (Jour intérieur)
- **Inside Day** : Jour où le High est inférieur au High précédent ET le Low est supérieur au Low précédent
- Si `PrecedeByInsideDay = true` : Les trades ne sont autorisés qu'après un inside day
- Si `PrecedeByInsideDay = false` : Les trades sont autorisés tous les jours

#### Holding Overnight (Maintien durant la nuit)
- Si `HoldOvernight = true` : Les positions sont maintenues jusqu'au signal inverse ou à la fermeture manuelle
- Si `HoldOvernight = false` : Les positions sont fermées automatiquement :
  - À l'ouverture du nouveau jour
  - À l'heure de fin de session (`SessionEndHour:SessionEndMinute`)

## Paramètres d'entrée

### Breakout Settings (Paramètres de Breakout)

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| BOoption | int | 1 | 1 = Fixed point, 2 = Volatility |
| FixedPoint | double | 1.6 | Niveau de breakout en points (si BOoption = 1) |
| VolPer | int | 20 | Période ATR pour volatilité (si BOoption = 2) |
| BreakoutFactor | double | 1.0 | Multiplicateur de volatilité |
| HoldOvernight | bool | false | Maintenir positions durant la nuit |
| PrecedeByInsideDay | bool | false | Exiger inside day avant trading |

### Volume Delta Settings (Paramètres Volume Delta)

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| VDPeriod | int | 14 | Période de calcul du Volume Delta |
| VDThreshold | double | 0.0 | Seuil de confirmation (positif pour achat, négatif pour vente) |

### Trading Settings (Paramètres de Trading)

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| LotSize | double | 0.1 | Taille de position en lots |
| MagicNumber | int | 123456 | Numéro magique de l'EA |
| TradeComment | string | "VDBrkout" | Commentaire des trades |

### Session Settings (Paramètres de Session)

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| SessionEndHour | int | 23 | Heure de fin de session |
| SessionEndMinute | int | 0 | Minute de fin de session |

## Logique de Trading

### Au début de chaque nouveau jour :

1. **Mise à jour des valeurs historiques**
   - ppHigh/ppLow : Hauts/Bas d'il y a 2 jours
   - pHigh/pLow : Hauts/Bas d'hier
   - tOpen/tHigh/tLow : Prix d'aujourd'hui

2. **Détection Inside Day**
   - Vérifie si hier était un inside day
   - Met à jour le flag `insideDay`

3. **Calcul du Breakout Level**
   - Selon l'option choisie (Fixed ou Volatility)

4. **Fermeture positions overnight**
   - Si `HoldOvernight = false`, ferme les positions ouvertes

### À chaque tick :

1. **Mise à jour High/Low du jour**
   - Actualise tHigh et tLow

2. **Vérification des signaux de breakout**
   - Calcule le Volume Delta actuel
   - Vérifie si le prix a cassé les niveaux
   - Confirme avec Volume Delta avant d'entrer

3. **Vérification fin de session**
   - Si temps >= SessionEnd et HoldOvernight = false
   - Ferme toutes les positions

## Exemples d'utilisation

### Configuration 1 : Breakout conservateur avec confirmation forte

```
BOoption = 1 (Fixed Point)
FixedPoint = 2.0
VDPeriod = 14
VDThreshold = 100.0
HoldOvernight = false
PrecedeByInsideDay = true
```

Cette configuration :
- Utilise un breakout fixe de 2 points
- Exige un Volume Delta ≥ 100 pour les achats
- Exige un Volume Delta ≤ -100 pour les ventes
- Ne trade qu'après un inside day
- Ferme positions en fin de journée

### Configuration 2 : Breakout volatilité avec confirmation modérée

```
BOoption = 2 (Volatility)
VolPer = 20
BreakoutFactor = 1.5
VDPeriod = 10
VDThreshold = 50.0
HoldOvernight = true
PrecedeByInsideDay = false
```

Cette configuration :
- Utilise ATR(20) × 1.5 comme niveau de breakout
- Exige un Volume Delta ≥ 50 pour confirmation
- Trade tous les jours (pas besoin d'inside day)
- Maintient positions durant la nuit

## Avantages de l'intégration Volume Delta

1. **Filtrage des faux signaux**
   - Évite les breakouts sans conviction (faible volume)
   - Confirme la direction du mouvement

2. **Amélioration du timing d'entrée**
   - Entre seulement quand acheteurs/vendeurs dominent
   - Réduit les entrées contre-tendance

3. **Flexibilité**
   - Ajustable via `VDThreshold`
   - Peut être désactivé en mettant VDThreshold = 0

## Avertissements et Considérations

1. **Backtesting recommandé**
   - Testez toujours sur données historiques avant trading réel
   - Optimisez les paramètres pour votre marché

2. **Gestion du risque**
   - Utilisez un lot approprié à votre capital
   - Considérez l'ajout de Stop Loss et Take Profit

3. **Conditions de marché**
   - Fonctionne mieux sur marchés tendanciels
   - Peut générer des signaux fréquents en range

4. **Slippage et spread**
   - Les breakouts peuvent subir du slippage
   - Vérifiez les spreads pendant les heures de trading

## Support et Modifications

Pour toute question ou modification de l'EA, veuillez :
- Vérifier les logs de MetaTrader 5 (onglet Experts)
- Ajuster les paramètres selon vos besoins
- Tester en mode démo avant trading réel

---

**Version:** 1.00  
**Date:** 2024  
**Plateforme:** MetaTrader 5
