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
                        "createdAt TEXT NOT NULL DEFAULT (datetime('now')), " +
                        "updatedAt TEXT NOT NULL DEFAULT (datetime('now'))" +
                        ")")
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_powerups_name ON Powerups(name)")

            var tableInfo = tx.executeSql("PRAGMA table_info(Powerups)")
            var hasCardColor = false
            for (var i = 0; i < tableInfo.rows.length; ++i) {
                var column = tableInfo.rows.item(i)
                if (column && column.name === 'cardColor') {
                    hasCardColor = true
                    break
                }
            }
            if (!hasCardColor)
                tx.executeSql("ALTER TABLE Powerups ADD COLUMN cardColor TEXT NOT NULL DEFAULT 'blue'")
        })

        seedBuiltinsIfNeeded()
        schemaReady()
    }

    function fetchAllPowerups() {
        ensureSchema()
        var records = queryAll(
                    "SELECT uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor " +
                    "FROM Powerups ORDER BY name")

        if (!records.length) {
            seedBuiltinsIfNeeded()
            records = queryAll(
                        "SELECT uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor " +
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
            powerupCardColor: (row.cardColor || row.powerupCardColor || "blue")
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
                            "INSERT OR REPLACE INTO Powerups (uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor) " +
                            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
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
                                (powerup.powerupCardColor || "blue")
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
                    "SELECT uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor " +
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

        withTransaction(function(tx) {
            tx.executeSql(
                        "INSERT OR REPLACE INTO Powerups (uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor) " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        [uuid, name, target, targetSpec, specData, cardHealth, amount, operation, isCustom, cardColor])
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

        withTransaction(function(tx) {
            var result = tx.executeSql(
                        "UPDATE Powerups SET name = ?, target = ?, targetSpec = ?, targetSpecData = ?, cardHealth = ?, amount = ?, operation = ?, isCustom = ?, cardColor = ?, updatedAt = datetime('now') " +
                        "WHERE uuid = ?",
                        [name, target, targetSpec, specData, cardHealth, amount, operation, isCustom, cardColor, uuid])

            if (!result.rowsAffected)
                tx.executeSql(
                            "INSERT OR REPLACE INTO Powerups (uuid, name, target, targetSpec, targetSpecData, cardHealth, amount, operation, isCustom, cardColor) " +
                            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                            [uuid, name, target, targetSpec, specData, cardHealth, amount, operation, isCustom, cardColor])
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
                powerupCardColor: "red"
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
                powerupCardColor: "green"
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
                powerupCardColor: "blue"
            }
        ]
    }
}
