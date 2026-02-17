# EA ImpulseZigZag - Troubleshooting Guide

## Problème: L'EA n'arrive pas à trader

Cette guide vous aide à diagnostiquer pourquoi l'EA ne trade pas.

---

## ✅ SOLUTION RAPIDE

### Étape 1: Activer le Mode Debug
1. Cliquez-droit sur le graphique → Expert Advisors → Properties
2. Dans l'onglet "Inputs", changez **DebugMode** à **true**
3. Cliquez OK
4. Vérifiez l'onglet "Experts" pour des messages détaillés

### Étape 2: Vérifier les Messages dans l'Onglet "Experts"

L'EA affichera maintenant des informations détaillées sur pourquoi il ne trade pas.

---

## 🔍 DIAGNOSTICS PAR SYMPTÔME

### Symptôme 1: Aucun Message dans l'Onglet "Experts"

**Cause Probable:** EA pas attaché ou AutoTrading désactivé

**Solutions:**
1. ✅ Vérifier que l'EA est attaché au graphique (icône smiley en haut à droite)
2. ✅ Activer AutoTrading (bouton vert dans la barre d'outils MT5)
3. ✅ Vérifier que le graphique est en **M5** (5 minutes)

---

### Symptôme 2: Message "Already traded today - skipping"

**Cause:** Paramètre `OneTradePerDay` est activé et un trade a déjà été exécuté

**Solutions:**
1. ✅ Attendre le lendemain pour un nouveau trade
2. ✅ Ou désactiver `OneTradePerDay` dans les paramètres

---

### Symptôme 3: Message "Position already open - skipping"

**Cause:** Une position est déjà ouverte sur ce symbole

**Solutions:**
1. ✅ Fermer la position existante
2. ✅ Ou attendre que la position se ferme (SL/TP)

---

### Symptôme 4: Pas de Détection d'Impulse

#### Message: "✗ Range too small"

**Explication:** La bougie n'est pas assez grande par rapport à l'ATR

**Exemple de Debug:**
```
DEBUG IMPULSE CHECK:
  Range: 0.00015 | ATR: 0.00020
  Range/ATR: 0.75x (need: 1.8-3.0)  ← TROP PETIT!
```

**Solutions:**
- **Option 1:** Réduire `ImpulseMinATRMult` de 1.8 à 1.5 (moins strict)
- **Option 2:** Choisir une heure avec plus de volatilité
- **Option 3:** Attendre une bougie plus grande

#### Message: "✗ Range excessive (news?)"

**Explication:** La bougie est trop grande (probablement une news)

**Exemple:**
```
Range/ATR: 3.5x (need: 1.8-3.0)  ← TROP GRAND!
```

**Solutions:**
- **Option 1:** Augmenter `ImpulseMaxATRMult` de 3.0 à 3.5
- **Option 2:** Éviter les heures de news économiques
- **Bonne Pratique:** Garder ce filtre actif pour éviter les faux signaux

#### Message: "✗ Body too weak"

**Explication:** Le corps de la bougie est trop petit (beaucoup de mèches)

**Exemple:**
```
Body%: 45.0% (need: ≥60%)  ← PAS ASSEZ!
```

**Solutions:**
- **Option 1:** Réduire `ImpulseBodyPercent` de 60% à 50%
- **Option 2:** Attendre une bougie avec plus de conviction (body plus grand)

#### Message: "✗ Spread too high"

**Explication:** Le spread du broker est trop élevé

**Exemple:**
```
Spread: 35 (max: 30)  ← TROP ÉLEVÉ!
```

**Solutions:**
- **Option 1:** Augmenter `MaxSpreadPoints` (ex: de 30 à 50)
- **Option 2:** Trader pendant les heures de faible spread
- **Option 3:** Changer de broker (spread plus compétitif)

---

### Symptôme 5: Impulse Détectée mais Pas de Trade

#### État: WAITING_PULLBACK1

**Message Debug:**
```
DEBUG: WAITING_PULLBACK1 - Bars since impulse: 3
DEBUG PB1 (Bearish): Looking for pullback high between 1.09050 and 1.09120
DEBUG: No valid PB1 found yet
```

**Explication:** L'EA attend un premier pullback dans la zone 35-65%

**Solutions:**
1. ✅ **Être patient** - Le pullback peut prendre plusieurs bougies
2. ✅ Si timeout (>6 bougies), ajuster `PullbackMaxBars` à 8 ou 10
3. ✅ Si pullback trop faible, réduire `PullbackMinRetrace` de 0.35 à 0.30
4. ✅ Si pullback trop fort, augmenter `PullbackMaxRetrace` de 0.65 à 0.70

#### État: WAITING_PULLBACK2

**Message Debug:**
```
DEBUG: WAITING_PULLBACK2 - Bars since impulse: 5
```

**Explication:** Premier pullback trouvé, attend le deuxième (structure ZigZag)

**Solutions:**
1. ✅ Continuer à attendre (peut prendre quelques bougies)
2. ✅ La structure doit former: HH1 → LL → HH2 (où HH2 < HH1) pour bearish

#### Validation ZigZag Échoue

**Message:** "Invalid ZigZag: PB2 >= PB1"

**Explication:** Le second pullback n'est pas plus bas que le premier

**Solution:** Attendre une nouvelle opportunité (structure invalide)

---

### Symptôme 6: ZigZag Complet mais Pas de Trade

#### État: WAITING_TRIGGER

**Message Debug:**
```
DEBUG: WAITING_TRIGGER - Monitoring price for trigger at: 1.09025
```

**Explication:** L'EA attend que le prix casse le niveau de trigger

**Vérifications:**
1. ✅ Le prix doit **casser** le niveau de trigger
2. ✅ Pour un SELL: Bid doit être **≤** trigger level
3. ✅ Pour un BUY: Ask doit être **≥** trigger level

**Si le prix ne touche jamais le trigger:**
- C'est normal! Toutes les structures ne se confirment pas
- L'EA abandonnera après quelques bougies (timeout)
- Attendre la prochaine opportunité

---

## ⚙️ PARAMÈTRES RECOMMANDÉS PAR PROBLÈME

### Pour Marchés Calmes (Peu de Volatilité)

```
ImpulseMinATRMult = 1.5  (au lieu de 1.8)
ImpulseBodyPercent = 55.0  (au lieu de 60.0)
PullbackMinRetrace = 0.30  (au lieu de 0.35)
PullbackMaxRetrace = 0.70  (au lieu de 0.65)
PullbackMaxBars = 8  (au lieu de 6)
```

### Pour Marchés Volatils (Beaucoup de Mouvement)

```
ImpulseMinATRMult = 2.0  (au lieu de 1.8)
ImpulseMaxATRMult = 3.5  (au lieu de 3.0)
ImpulseBodyPercent = 65.0  (au lieu de 60.0)
PullbackMaxBars = 5  (au lieu de 6)
```

### Pour Plus de Signaux (Moins Strict)

```
ImpulseMinATRMult = 1.5
ImpulseBodyPercent = 50.0
PullbackMinRetrace = 0.25
PullbackMaxRetrace = 0.75
PullbackMaxBars = 10
MaxSpreadPoints = 50
```

### Pour Meilleure Qualité (Plus Strict)

```
ImpulseMinATRMult = 2.0
ImpulseBodyPercent = 70.0
PullbackMinRetrace = 0.40
PullbackMaxRetrace = 0.60
PullbackMaxBars = 5
MaxSpreadPoints = 20
```

---

## 📋 CHECKLIST DE VÉRIFICATION

Avant de contacter le support, vérifiez:

### Configuration MT5
- [ ] Graphique en **M5** (5 minutes)
- [ ] AutoTrading activé (bouton vert)
- [ ] EA attaché au graphique (smiley visible)
- [ ] Options → Expert Advisors → "Allow automated trading" ✓

### Configuration EA
- [ ] `EntryHour` et `EntryMinute` correctement configurés
- [ ] Heure du serveur MT5 vérifiée
- [ ] `DebugMode = true` pour diagnostics
- [ ] `TradeDirection` compatible avec le marché

### Conditions de Marché
- [ ] Spread acceptable (<30 points par défaut)
- [ ] Volatilité suffisante pour impulse
- [ ] Pas de position déjà ouverte
- [ ] Pas déjà tradé aujourd'hui (si OneTradePerDay=true)

---

## 🎯 EXEMPLE DE SESSION DEBUG COMPLÈTE

### Configuration Recommandée pour Tests
```
EntryHour = 8          // London Open (ajuster selon votre broker)
EntryMinute = 0
DebugMode = true       // IMPORTANT!
OneTradePerDay = false // Permet plusieurs tests
ImpulseMinATRMult = 1.5  // Moins strict pour tests
ImpulseBodyPercent = 55.0
```

### Messages Attendus (Succès)

```
════════════════════════════════════════
EA IMPULSE ZIGZAG - INITIALIZED
════════════════════════════════════════
Symbol: EURUSD
Timeframe: M5
Entry Time: 8:00
Debug Mode: ON
════════════════════════════════════════

[08:00] DEBUG: Checking for impulse. Bar time: 2026.02.17 08:00 | Entry time: 8:0 | Match: YES

DEBUG IMPULSE CHECK:
  Range: 0.00025 | ATR: 0.00020
  Range/ATR: 1.25x (need: 1.5-3.0)  ← OK!
  Body%: 68.5% (need: ≥55%)  ← OK!
  Spread: 15 (max: 30)  ← OK!

=== IMPULSE CANDLE DETECTED ===
Direction: BEARISH
Range: 0.00025 Points (1.25x ATR)
Body: 68.5%

✓ Impulse detected - Waiting for pullback

[08:05] DEBUG: WAITING_PULLBACK1 - Bars since impulse: 1
DEBUG PB1 (Bearish): Looking for pullback high between 1.09075 and 1.09135

[08:10] ✓ Pullback 1 detected at: 1.09110 (bar: 2)

[08:15] DEBUG: WAITING_PULLBACK2 - Bars since impulse: 3

[08:20] ✓ Pullback 2 detected at: 1.09090 (lower than PB1: 1.09110)

=== BEARISH ZIGZAG VALID ===
Impulse Low: 1.09000
Pullback1 High: 1.09110
Rejection Low: 1.09055
Pullback2 High: 1.09090 (< PB1)

Trigger SELL at: 1.09045

✓ ZigZag complete - Waiting for trigger

[08:22] DEBUG: WAITING_TRIGGER - Monitoring price for trigger at: 1.09045

[08:23] 🔴 SELL TRIGGER ACTIVATED!

════════════════════════════════════════
✅ TRADE EXECUTED!
════════════════════════════════════════
Type: SELL
Ticket: 123456789
Price: 1.09043
Lot: 0.10
SL: 1.09120 (77 points)
TP: 1.08889 (154 points)
R:R: 1:2.00
════════════════════════════════════════
```

---

## 🆘 PROBLÈMES FRÉQUENTS ET SOLUTIONS

### "EA doit être attaché sur M5"
**Solution:** Changez le timeframe du graphique à M5 (clic-droit → Timeframe → M5)

### "Aucun message après initialisation"
**Solution:** 
1. Vérifiez que vous êtes à l'heure d'entrée configurée
2. Activez DebugMode pour voir les vérifications
3. Attendez la prochaine bougie M5

### "Toujours en WAITING_IMPULSE"
**Solutions:**
1. Vérifiez l'heure du serveur MT5 (coin inférieur droit)
2. Ajustez `EntryHour` pour correspondre
3. Assouplissez les critères (ImpulseMinATRMult, ImpulseBodyPercent)

### "Timeout pullback"
**Solutions:**
1. Augmentez `PullbackMaxBars` à 8-10
2. Élargissez la zone de retracement (PullbackMinRetrace/MaxRetrace)

---

## 📞 SUPPORT

Si le problème persiste après avoir suivi ce guide:

1. **Activer DebugMode = true**
2. **Copier TOUS les messages de l'onglet Experts**
3. **Noter vos paramètres EA**
4. **Prendre une capture d'écran du graphique**
5. **Contacter le support avec ces informations**

---

## 📊 STATISTIQUES NORMALES

**Combien de trades par jour?**
- Avec `OneTradePerDay=true`: Maximum 1 trade
- Dépend des conditions de marché
- Certains jours: aucun trade (c'est normal!)

**Taux de succès attendu?**
- Structure valide formée: ~30-50% des jours
- Trade exécuté: ~20-40% des structures
- Ne pas s'attendre à trader chaque jour

**Temps d'attente?**
- Détection impulse: À l'heure d'entrée exacte
- Formation ZigZag: 2-6 bougies M5 (10-30 minutes)
- Trigger: Peut être immédiat ou ne jamais se produire

---

**Dernière mise à jour:** 17 février 2026  
**Version EA:** 1.10
