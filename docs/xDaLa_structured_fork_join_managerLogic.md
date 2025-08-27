# XGR Manager – Prozess-/Join-Spezifikation (v0, lean & clean)

> **Kurzfassung:** Minimale, generische Ausführungs-Engine für XRC‑729‑orchestrierte Validierungsschritte (XRC‑137). Fokus: deterministische Fork/Join‑Abläufe, sofortige Speicherfreigabe (GC), null Ballast.

---

## 1) Grundprinzipien

**Node = **``\
Jeder Ausführungsknoten ist eine eigenständige Entität im Store. Ein Orchestrierungsdurchlauf (vom RPC gestartet) erzeugt im Zeitverlauf **1..n** solcher Nodes.

**IDs**

| Feld            | Bedeutung                                  | Setzung / Herkunft                                                    |
| --------------- | ------------------------------------------ | --------------------------------------------------------------------- |
| `RootPid`       | Gemeinsame ID für alle Nodes einer Session | Vom Manager pro Workflow gesetzt                                      |
| `ProcessId`     | Eindeutig pro Node                         | Vom Manager vergeben                                                  |
| `ThreadHeadPid` | Kennung des Threads                        | **spawn** → `ProcessId` des Child · **continue** → vom Parent vererbt |

**Lean GC**

- Nach `ValidateSingleStep` und dem Erzeugen der im Edge definierten **spawns/continue** wird der ausführende Node gelöscht (tombstone/kill), sofern sein Ergebnis ggf. zuvor ins Join‑Postfach zugestellt wurde (siehe §4).
- Ergebnisdaten werden **nicht** dauerhaft am Node gehalten; sie gehen nur
  - an das **Join‑Ziel** (falls benötigt) und
  - in **on‑chain Receipts** (außerhalb des Managers).

> Ergebnis: Keine Speicherflut – auch bei langen (Sub‑)Ketten.

---

## 2) Zustände & Scheduling

**SessionStatus**

| Status  | Bedeutung                                             |
| ------- | ----------------------------------------------------- |
| Waiting | Node wartet (z. B. wegen `waitOnJoin` oder `waitMs`). |
| Running | Zur Ausführung freigegeben.                           |
| Done    | Abgeschlossen (danach löschen, siehe GC).             |
| Aborted | Abgebrochen (Fehler/Unmöglichkeit).                   |

**Tick‑Loop (Manager)**

- Liste aller Nodes aus dem Store lesen.
- **Join‑Targets** (Nodes mit Postfach‑Metadaten, §3) **nie** über `NextWakeAt` promoten, sondern **nur** über Postfach‑Vollständigkeit.
- Alle übrigen **Waiting** Nodes mit `NextWakeAt <= now` → **Running**.
- **Running** Nodes werden in **Goroutinen** mit **inFlight‑Guard** ausgeführt.

**inFlight‑Guard**

- Pro `owner#processId` genau **eine** Ausführung zulassen (kein Doppelstart).

---

## 3) Join – Datenmodell (am Join‑Target)

Das **Join‑Target** ist der **Continue‑Node** des Elternschritts mit `waitOnJoin:true`. Es besitzt ein **Postfach** und Join‑Metadaten in `ResumePlain`.

```jsonc
// Nur auf dem Join‑Target gespeichert (keinen globalen Zustand nötig)
{
  "__expect": ["toB", "toC"],               // erwartete Labels; Quelle: join.inputs[].label
  "__exactFrom": { "toC": "C2" },           // optional für mode:"exact": Stück MUSS von StepId kommen
  "__threads": { "toB": "<pid>", "toC": "<pid>" }, // Label → ThreadHeadPid der Spawn‑Threads

  // Postfach
  "__join": { "toB": { /* Payload */ }, "toC": { /* Payload */ } },
  "__joinFrom": { "toB": "B2", "toC": "C2" }       // tatsächliche StepIds der liefernden Nodes
}
```

> Falls `__expect` nicht gesetzt: Fallback = Menge der `__threads`‑Keys.

---

## 4) Routing & Zustellung

### 4.1 Erzeugung von **Continue** + **Spawns** (Parent → Children)

1. **Continue zuerst** erzeugen.
   - Bei `continue.waitOnJoin:true`: Continue‑Node als **Waiting** anlegen und `__expect`, `__exactFrom`, `__threads` initialisieren.
2. **Spawns** erzeugen.
   - Jeder Spawn erhält einen **neuen Thread** (`ThreadHeadPid = ProcessId` des Child).
   - Routing zum Join‑Target setzen:
     - `JoinTargetPid` = PID des Continue‑Nodes
     - `JoinLabel` = Spawn‑Label
     - `JoinMode` ∈ {`exact`, `any`}
     - `JoinFrom` = gewünschter `StepId` (nur bei `exact`)
   - Die `ThreadHeadPid` des Child unter `__threads[label]` **am Join‑Target** eintragen.
3. **Parent‑GC**: Nach Erzeugen von Continue/Spawns Parent auf **Done** setzen und gem. §6 löschen (nach evtl. Zustellung).

### 4.2 Zustellung durch **Kind‑Nodes** (Child → Join‑Target)

Sobald ein Kind‑Node **Done** ist **und** `JoinTargetPid ≠ ""`:

1. **Atomar** mit **Join‑Lock** (pro Join‑Target):
   - Join‑Target **frisch** lesen (gegen Races).
   - `JoinMode` prüfen:
     - **exact**: `LastStep` des Child **muss** `JoinFrom` entsprechen.
     - **any**: Child **muss terminal** im **eigenen Thread** sein (siehe 4.3).
   - Stück einlegen: `__join[JoinLabel] = ResumePlain`.
   - `__joinFrom[JoinLabel] = LastStep` setzen (für `exact`).
   - Join‑Target zurückschreiben.
2. **Child löschen** (GC).

> **Warum Lock?** Mehrere parallel fertig werdende Kinder derselben Join‑Instanz dürfen sich nicht überschreiben → Mutex pro `owner#JoinTargetPid`.

### 4.3 Terminalitäts‑Prüfung für `any`

Ein Stück aus `any` wird nur akzeptiert, wenn der Child‑Node **terminal** im eigenen Thread ist:

> **Terminal** ⇢ Im Store **existiert kein weiterer Node** mit `ThreadHeadPid == this.ThreadHeadPid` **und** `ParentPid == this.ProcessId`.

Damit sammelt `any` immer die **letzte** Version des Thread‑Outputs (Leaf‑Semantik), nie Zwischenstände.

---

## 5) Join‑Promotion & Impossibilitäts‑Erkennung

### 5.1 Promotion (Waiting → Running)

Ein Join‑Target wird **nur** promotet, wenn seine Inbox **vollständig** ist:

- Für **jedes** erwartete `label ∈ __expect` gilt:
  - `__join[label]` existiert und
  - falls `__exactFrom[label]` gesetzt ist: `__joinFrom[label]` **matcht**.
- Danach: Alle Stücke (Bag‑Semantik) ins normale `ResumePlain` des Join‑Targets **mergen** (last‑wins).
- **Aufräumen:** `__join`, `__joinFrom`, `__exactFrom`, `__expect`, `__threads` **löschen**.
- `Status = Running`, `NextWakeAt = 0`.

> **Wichtig:** Join‑Targets **nie** über `NextWakeAt` promoten – ausschließlich über Inbox‑Vollständigkeit.

### 5.2 Unmöglichkeit (Abort)

Ein Join kann nicht erfüllt werden, wenn ein erwartetes Label unwiederbringlich ausfällt:

- **Kriterium pro Label:**
  - Es liegt **kein** Stück in `__join[label]`, **und**
  - im Store existiert **kein** Node mehr mit `ThreadHeadPid == __threads[label]`.
- **Folge:** Join‑Target auf **Aborted** setzen und löschen; übergeordneter Join/Thread entscheidet analog (**Kaskaden‑Abort** möglich).

> Fehler in Sub/Sub‑Prozessen propagieren deterministisch nach oben.

---

## 6) Lösch‑/GC‑Regeln (einheitlich)

- **Parent**: nach Erzeugen seiner Kanten (spawns/continue) und ggf. Zustellung löschen.
- **Child**: nach Zustellung (bei Join‑Routing) bzw. direkt (ohne Join‑Target) löschen.
- **Join‑Target**:\
  – nach **Promotion** läuft es normal weiter und wird nach eigener Kante gelöscht.\
  – bei **Unmöglichkeit**: `Aborted` und löschen.

> Der Store enthält nur aktive **Waiting/Running**‑Nodes der aktuellen Wellen sowie **Join‑Targets** in Warteposition. Historie/Receipts: **on‑chain**.

---

## 7) Fehler‑Semantik

- **Harte Fehler** in `ValidateSingleStep` (nicht retrybar): Node sofort löschen (Thread terminiert ohne Stück). Betroffene Join‑Targets erkennen Unmöglichkeit (vgl. §5.2) und brechen ab (Kaskade möglich).
- **Transient** (z. B. RPC‑Glitch): Backoff optional. Für **v0 (lean)** empfohlen: **Kill** statt Retry → keine hängenden Threads.

---

## 8) Datenfluss – Wohin wird geschrieben?

- **Continue (ohne Join):** Payload → direkt als `ResumePlain` des Continue‑Nodes.
- ``**:** Payload wird **nicht** direkt gesetzt, sondern\
  – bei den **Spawns** als Stücke abgelegt und\
  – im **Join** nach Vollständigkeit **gemerged** (Bag‑Semantik).
- **Keine Encryption im Manager:** `EncryptedPayload/Keys` sind entfernt. E2E‑Verschlüsselung ggf. **extern** (späteres Backend).

---

## 9) Tiefe/Schachtelung (Sub/Sub‑Prozesse)

- **Join‑Routing wird vererbt:** Erzeugt ein Child weitere Kinder, vererbt es `JoinTargetPid/JoinLabel/JoinMode/JoinFrom` an deren Kinder – bis ein terminaler Producer liefert.
- Es liefern nur **direkte Kind‑Threads** (aus Sicht des Join‑Targets), **nie** Geschwister anderer Join‑Ebenen.
- ``** in der Tiefe:** sammelt nur aus dem **Kind‑Thread** (nicht tiefer), dort jeweils die **terminalen** Ergebnisse (Leaf).

---

## 10) Sicherheit & Race‑Freiheit

- **Atomic Delivery:** Mutex pro `owner#pid` → keine verlorenen Stücke.
- **Fresh Read** vor Promotion: Join‑Target frisch laden.
- **No Doppelstart:** `inFlight` + atomischer Wechsel `Waiting → Running`.
- **Join‑Kandidaten** sind von `NextWakeAt`‑Promotion **ausgenommen**.

---

## 11) Schnittstellen & Effekte

- **RPC‑Entry (**``**)**: Prüft Permit/Domain, enqueued Start‑Node (StepId aus RPC), setzt `Status = Running/Waiting` gemäß `waitMs`.
- **Orchestration (XRC‑729)**: Einmalig laden und **per **``** cachen**.
- ``** (Engine/XRC‑137)**: Liefert Effects (`Status`, `LastStep`, `ResumeStep`, `NextWakeAt`, neues `ResumePlain`, `ResultValid`, …).
- **Manager**: Setzt State aus Effects, erzeugt Kanten (Continue/Spawns), führt **GC/Zustellung** aus.

---

## 12) Zusammenfassung als Checkliste

-

---

## 13) Optionale Tunables (bleiben „aus“, solange *lean*)

- **Timeouts** für Join (`XRC‑729 timeoutSec`): derzeit **inaktiv**; v0 verlässt sich auf Unmöglichkeits‑Erkennung.
- **Retry‑Policy** bei Transienten: v0 empfiehlt **Kill** (simpel); spätere Differenzierung möglich.

