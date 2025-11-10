import QtQuick 2.15
import QtQuick.LocalStorage 2.15

QtObject {
    id: powerupDatabase

    property string databaseName: "BlockwarsPowerups"
    property string databaseVersion: "1.0"
    property string databaseLabel: "Blockwars Powerup Database"
    property int estimatedSize: 5 * 1024 * 1024 // 5 MB allocation to keep headroom for future data
    property var __connection: null

    signal schemaReady()

    function open() {
        if (__connection)
            return __connection

        __connection = LocalStorage.openDatabaseSync(
                    databaseName,
                    databaseVersion,
                    databaseLabel,
                    estimatedSize)
        return __connection
    }

    function withTransaction(callback) {
        var db = open()
        if (!db || typeof callback !== "function")
            return

        db.transaction(function(tx) {
            callback(tx)
        })
    }

    function execute(sql, parameters) {
        var lastResult = null
        withTransaction(function(tx) {
            lastResult = tx.executeSql(sql, parameters || [])
        })
        return lastResult
    }

    function queryAll(sql, parameters) {
        var rows = []
        withTransaction(function(tx) {
            var rs = tx.executeSql(sql, parameters || [])
            for (var i = 0; i < rs.rows.length; ++i) {
                rows.push(rs.rows.item(i))
            }
        })
        return rows
    }

    function normalizeHeroSpan(value) {
        var span = Number(value)
        if (!isFinite(span))
            span = 1
        span = Math.floor(span)
        if (span < 1)
            span = 1
        if (span > 6)
            span = 6
        return span
    }

    function normalizeIconIndex(value) {
        var icon = Number(value)
        if (!isFinite(icon))
            icon = 0
        icon = Math.floor(icon)
        if (icon < 0)
            icon = 0
        if (icon >= 25 && 25 > 0)
            icon = icon % 25
        return icon
    }

    function ensureSchema() {
        withTransaction(function(tx) {
            tx.executeSql(
                        "CREATE TABLE IF NOT EXISTS Powerups (" +
                        "uuid TEXT PRIMARY KEY, " +
                        "name TEXT NOT NULL, " +
                        "target TEXT NOT NULL, " +
                        "targetSpec TEXT NOT NULL, " +
                        "targetSpecData TEXT, " +
                        "cardHealth INTEGER NOT NULL DEFAULT 0, " +
                        "amount INTEGER NOT NULL DEFAULT 0, " +
                        "operation TEXT NOT NULL, " +
                        "isCustom INTEGER NOT NULL DEFAULT 0, " +
                        "cardColor TEXT NOT NULL DEFAULT 'blue', " +
                        "heroRowSpan INTEGER NOT NULL DEFAULT 1, " +
                        "heroColSpan INTEGER NOT NULL DEFAULT 1, " +
                        "cardIcon INTEGER NOT NULL DEFAULT 0, " +
                        "createdAt TEXT NOT NULL DEFAULT (datetime('now')), " +
                        "updatedAt TEXT NOT NULL DEFAULT (datetime('now'))" +
                        ")")
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_powerups_name ON Powerups(name)")

            var tableInfo = tx.executeSql("PRAGMA table_info(Powerups)")
            var hasCardColor = false
            var hasHeroRowSpan = false
            var hasHeroColSpan = false
            var hasCardIcon = false
            for (var i = 0; i < tableInfo.rows.length; ++i) {
                var column = tableInfo.rows.item(i)
                if (!column)
                    continue
                if (column.name === 'cardColor')
                    hasCardColor = true
                else if (column.name === 'heroRowSpan')
                    hasHeroRowSpan = true
                else if (column.name === 'heroColSpan')
                    hasHeroColSpan = true
                else if (column.name === 'cardIcon')
                    hasCardIcon = true
            }
            if (!hasCardColor)
                tx.executeSql("ALTER TABLE Powerups ADD COLUMN cardColor TEXT NOT NULL DEFAULT 'blue'")
            if (!hasHeroRowSpan)
                tx.executeSql("ALTER TABLE Powerups ADD COLUMN heroRowSpan INTEGER NOT NULL DEFAULT 1")
            if (!hasHeroColSpan)
                tx.executeSql("ALTER TABLE Powerups ADD COLUMN heroColSpan INTEGER NOT NULL DEFAULT 1")
            if (!hasCardIcon)
                tx.executeSql("ALTER TABLE Powerups ADD COLUMN cardIcon INTEGER NOT NULL DEFAULT 0")
            tx.executeSql(
                        "CREATE TABLE IF NOT EXISTS PlayerLoadout (" +
                        "slot INTEGER PRIMARY KEY CHECK(slot >= 0 AND slot < 4), " +
                        "powerupUuid TEXT, " +
                        "updatedAt TEXT NOT NULL DEFAULT (datetime('now'))" +
                        ")")
            tx.executeSql("CREATE UNIQUE INDEX IF NOT EXISTS idx_loadout_powerup ON PlayerLoadout(powerupUuid)")
        })

        seedBuiltinsIfNeeded()
        schemaReady()
    }

    function fetchAllPowerups() {
        ensureSchema()
        var records = queryAll(
                    "SELECT uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor, heroRowSpan, heroColSpan, cardIcon " +
                    "FROM Powerups ORDER BY name")

        if (!records.length) {
            seedBuiltinsIfNeeded()
            records = queryAll(
                        "SELECT uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor, heroRowSpan, heroColSpan, cardIcon " +
                        "FROM Powerups ORDER BY name")
        }

        if (!records.length)
            return builtinPowerups()

        var mapped = []
        for (var i = 0; i < records.length; ++i)
            mapped.push(mapRowToPowerup(records[i]))
        return mapped
    }

    function mapRowToPowerup(row) {
        var rawData = row.targetSpecData || row.powerupTargetSpecData
        var parsedData = rawData
        if (typeof rawData === "string" && rawData.length) {
            try {
                parsedData = JSON.parse(rawData)
            } catch (error) {
                parsedData = rawData
            }
        }

        var heroRows = normalizeHeroSpan(row.heroRowSpan || row.powerupHeroRowSpan || 1)
        var heroCols = normalizeHeroSpan(row.heroColSpan || row.powerupHeroColSpan || 1)

        return {
            powerupUuid: row.uuid || row.powerupUuid || "",
            powerupName: row.name || row.powerupName || "",
            powerupTarget: row.target || row.powerupTarget || "Self",
            powerupTargetSpec: row.targetSpec || row.powerupTargetSpec || "PlayerHealth",
            powerupTargetSpecData: parsedData !== undefined ? parsedData : [],
            powerupCardHealth: row.cardHealth || row.powerupCardHealth || 0,
            powerupActualAmount: row.amount || row.powerupActualAmount || 0,
            powerupOperation: row.operation || row.powerupOperation || "increase",
            powerupIsCustom: !!(row.isCustom || row.powerupIsCustom),
            powerupCardColor: (row.cardColor || row.powerupCardColor || "blue"),
            powerupHeroRowSpan: heroRows,
            powerupHeroColSpan: heroCols,
            powerupIcon: normalizeIconIndex(row.cardIcon !== undefined ? row.cardIcon : row.powerupIcon)
        }
    }

    function seedBuiltinsIfNeeded() {
        withTransaction(function(tx) {
            var rs = tx.executeSql("SELECT COUNT(*) AS count FROM Powerups")
            var shouldSeed = rs.rows.length && rs.rows.item(0).count === 0
            if (!shouldSeed)
                return

            var builtins = builtinPowerups()
            for (var i = 0; i < builtins.length; ++i) {
                var powerup = builtins[i]
                var serialized = null
                if (powerup.powerupTargetSpecData !== null && powerup.powerupTargetSpecData !== undefined)
                    serialized = JSON.stringify(powerup.powerupTargetSpecData)

                tx.executeSql(
                            "INSERT OR REPLACE INTO Powerups (uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor, heroRowSpan, heroColSpan, cardIcon) " +
                            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                            [
                                powerup.powerupUuid,
                                powerup.powerupName,
                                powerup.powerupTarget,
                                powerup.powerupTargetSpec,
                                serialized,
                                powerup.powerupCardHealth || 0,
                                powerup.powerupActualAmount || 0,
                                powerup.powerupOperation || "increase",
                                powerup.powerupIsCustom ? 1 : 0,
                                (powerup.powerupCardColor || "blue"),
                                normalizeHeroSpan(powerup.powerupHeroRowSpan || 1),
                                normalizeHeroSpan(powerup.powerupHeroColSpan || 1),
                                powerup.powerupIcon || 0
                            ])
            }
        })
    }


    function generatePowerupUuid() {
        return 'powerup-' + Date.now().toString(16) + '-' + Math.floor(Math.random() * 1e9).toString(16)
    }

    function serializeTargetSpecDataForStorage(targetSpec, data) {
        if (targetSpec === 'Blocks') {
            var sanitized = []
            if (Array.isArray(data)) {
                for (var i = 0; i < data.length; ++i) {
                    var entry = data[i]
                    if (entry && entry.row !== undefined && entry.col !== undefined) {
                        sanitized.push({ row: Number(entry.row) || 0, col: Number(entry.col) || 0 })
                    }
                }
            }
            return JSON.stringify(sanitized)
        }

        if (targetSpec === 'PlayerPowerupInGameCards') {
            if (typeof data === 'string' && data.length)
                return data
            if (data && data.color)
                return data.color
            return 'blue'
        }

        return null
    }

    function fetchPowerup(uuid) {
        if (!uuid)
            return null
        var rows = queryAll(
                    "SELECT uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor, heroRowSpan, heroColSpan, cardIcon " +
                    "FROM Powerups WHERE uuid = ?",
                    [uuid])
        if (!rows.length)
            return null
        return mapRowToPowerup(rows[0])
    }

    function createPowerup(initialValues) {
        var record = initialValues || {}
        var uuid = record.powerupUuid || generatePowerupUuid()
        var name = record.powerupName || qsTr('New Powerup')
        var target = record.powerupTarget || 'Self'
        var targetSpec = record.powerupTargetSpec || 'PlayerHealth'
        var specData = serializeTargetSpecDataForStorage(targetSpec, record.powerupTargetSpecData)
        var cardHealth = record.powerupCardHealth || 0
        var amount = record.powerupActualAmount || 0
        var operation = target === 'Enemy' ? 'decrease' : 'increase'
        var isCustom = record.powerupIsCustom === false ? 0 : 1
        var cardColor = (record.powerupCardColor || 'blue')
        var heroRowSpan = normalizeHeroSpan(record.powerupHeroRowSpan || 1)
        var heroColSpan = normalizeHeroSpan(record.powerupHeroColSpan || 1)
        var cardIcon = normalizeIconIndex(record.powerupIcon || 0)

        withTransaction(function(tx) {
            tx.executeSql(
                        "INSERT OR REPLACE INTO Powerups (uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor, heroRowSpan, heroColSpan, cardIcon) " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        [uuid, name, target, targetSpec, specData, cardHealth, amount, operation, isCustom, cardColor, heroRowSpan, heroColSpan, cardIcon])
        })

        return fetchPowerup(uuid)
    }

    function savePowerup(powerup) {
        if (!powerup || !powerup.powerupUuid)
            return null

        var uuid = powerup.powerupUuid
        var name = powerup.powerupName || ''
        var target = powerup.powerupTarget || 'Self'
        var targetSpec = powerup.powerupTargetSpec || 'PlayerHealth'
        var specData = serializeTargetSpecDataForStorage(targetSpec, powerup.powerupTargetSpecData)
        var cardHealth = Number(powerup.powerupCardHealth) || 0
        var amount = Number(powerup.powerupActualAmount) || 0
        var operation = target === 'Enemy' ? 'decrease' : (powerup.powerupOperation || 'increase')
        var isCustom = powerup.powerupIsCustom ? 1 : 0
        var cardColor = (powerup.powerupCardColor || 'blue')
        var heroRowSpan = normalizeHeroSpan(powerup.powerupHeroRowSpan || 1)
        var heroColSpan = normalizeHeroSpan(powerup.powerupHeroColSpan || 1)
        var cardIcon = normalizeIconIndex(powerup.powerupIcon || 0)

        withTransaction(function(tx) {
            var result = tx.executeSql(
                        "UPDATE Powerups SET name = ?, target = ?, targetSpec = ?, targetSpecData = ?, cardHealth = ?, amount = ?, operation = ?, isCustom = ?, cardColor = ?, heroRowSpan = ?, heroColSpan = ?, cardIcon = ?, updatedAt = datetime('now') " +
                        "WHERE uuid = ?",
                        [name, target, targetSpec, specData, cardHealth, amount, operation, isCustom, cardColor, heroRowSpan, heroColSpan, cardIcon, uuid])

            if (!result.rowsAffected)
                tx.executeSql(
                            "INSERT OR REPLACE INTO Powerups (uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor, heroRowSpan, heroColSpan, cardIcon) " +
                            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                            [uuid, name, target, targetSpec, specData, cardHealth, amount, operation, isCustom, cardColor, heroRowSpan, heroColSpan, cardIcon])
        })

        return fetchPowerup(uuid)
    }

    function deletePowerup(uuid) {
        if (!uuid)
            return false
        var affected = 0
        withTransaction(function(tx) {
            var result = tx.executeSql("DELETE FROM Powerups WHERE uuid = ?", [uuid])
            affected = result.rowsAffected
        })
        return affected > 0
    }

    function normalizeLoadoutRows(rows) {
        var loadout = [null, null, null, null]
        for (var i = 0; i < rows.length; ++i) {
            var row = rows[i]
            if (row.slot === undefined || row.slot === null)
                continue
            if (!row.uuid) {
                withTransaction(function(tx) {
                    tx.executeSql("DELETE FROM PlayerLoadout WHERE slot = ?", [row.slot])
                })
                continue
            }
            loadout[row.slot] = mapRowToPowerup(row)
        }
        var result = []
        for (var slot = 0; slot < 4; ++slot) {
            result.push({ slot: slot, powerup: loadout[slot] })
        }
        return result
    }

    function fetchLoadout() {
        ensureSchema()
        var rows = queryAll(
                    "SELECT l.slot AS slot, p.uuid AS uuid, p.name AS name, p.target AS target, p.targetSpec AS targetSpec, " +
                    "p.targetSpecData AS targetSpecData, p.cardHealth AS cardHealth, p.amount AS amount, p.operation AS operation, " +
                    "p.isCustom AS isCustom, p.cardColor AS cardColor, p.heroRowSpan AS heroRowSpan, p.heroColSpan AS heroColSpan, p.cardIcon AS cardIcon " +
                    "FROM PlayerLoadout l LEFT JOIN Powerups p ON p.uuid = l.powerupUuid ORDER BY l.slot")
        var normalized = normalizeLoadoutRows(rows)
        var populateDefaults = true
        for (var i = 0; i < normalized.length; ++i) {
            if (normalized[i] && normalized[i].powerup) {
                populateDefaults = false
                break
            }
        }
        if (!populateDefaults)
            return normalized

        var builtins = builtinPowerups()
        for (var slot = 0; slot < normalized.length && slot < builtins.length; ++slot)
            normalized[slot] = { slot: slot, powerup: builtins[slot] }
        return normalized
    }

    function setLoadoutSlot(slot, powerupUuid) {
        ensureSchema()
        if (slot === undefined || slot === null)
            return fetchLoadout()
        slot = Number(slot)
        if (slot < 0 || slot > 3)
            return fetchLoadout()

        withTransaction(function(tx) {
            tx.executeSql("DELETE FROM PlayerLoadout WHERE slot = ?", [slot])
            if (powerupUuid) {
                tx.executeSql("DELETE FROM PlayerLoadout WHERE powerupUuid = ?", [powerupUuid])
                tx.executeSql("INSERT OR REPLACE INTO PlayerLoadout (slot, powerupUuid, updatedAt) VALUES (?, ?, datetime('now'))", [slot, powerupUuid])
            }
        })

        return fetchLoadout()
    }

    function clearLoadout() {
        withTransaction(function(tx) {
            tx.executeSql("DELETE FROM PlayerLoadout")
        })
    }

    function builtinPowerups() {
        return [
            {
                powerupUuid: "builtin-meteor-strike",
                powerupName: qsTr("Meteor Strike"),
                powerupTarget: "Enemy",
                powerupTargetSpec: "Blocks",
                powerupTargetSpecData: [
                    { row: 0, col: 2 }, { row: 0, col: 3 }, { row: 1, col: 2 },
                    { row: 1, col: 3 }, { row: 2, col: 2 }, { row: 2, col: 3 }
                ],
                powerupCardHealth: 0,
                powerupActualAmount: 6,
                powerupOperation: "decrease",
                powerupIsCustom: false,
                powerupCardColor: "red",
                powerupHeroRowSpan: 2,
                powerupHeroColSpan: 2,
                powerupIcon: 0
            },
            {
                powerupUuid: "builtin-aegis-surge",
                powerupName: qsTr("Aegis Surge"),
                powerupTarget: "Self",
                powerupTargetSpec: "PlayerHealth",
                powerupTargetSpecData: null,
                powerupCardHealth: 5,
                powerupActualAmount: 8,
                powerupOperation: "increase",
                powerupIsCustom: false,
                powerupCardColor: "green",
                powerupHeroRowSpan: 1,
                powerupHeroColSpan: 1,
                powerupIcon: 1
            },
            {
                powerupUuid: "builtin-arcane-draw",
                powerupName: qsTr("Arcane Draw"),
                powerupTarget: "Self",
                powerupTargetSpec: "PlayerPowerupInGameCards",
                powerupTargetSpecData: "purple",
                powerupCardHealth: 2,
                powerupActualAmount: 3,
                powerupOperation: "increase",
                powerupIsCustom: false,
                powerupCardColor: "blue",
                powerupHeroRowSpan: 1,
                powerupHeroColSpan: 1,
                powerupIcon: 2
            }
        ]
    }
}
