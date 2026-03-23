#!/bin/bash

echo "🚀 Начало инициализации шардированного кластера MongoDB"

###
# Инициализация Replica Set для Config Server'а
###
echo "🔧 Инициализация Config Server (configsrv1:27019)..."
docker compose exec -T configsrv1 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "configReplSet", 
  configsvr: true, 
  members: [{_id: 0, host: "configsrv1:27019"}]
})
EOF
echo "✅ Config Server инициализирован"

###
# Инициализация Replica Set для Shard 1
###
echo "🔧 Инициализация Shard 1 (shard1:27018)..."
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet", 
  members: [{_id: 0, host: "shard1:27018"}]
})
EOF
echo "✅ Shard 1 инициализирован"

###
# Инициализация Replica Set для Shard 2
###
echo "🔧 Инициализация Shard 2 (shard2:27020)..."
docker compose exec -T shard2 mongosh --port 27020 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet", 
  members: [{_id: 0, host: "shard2:27020"}]
})
EOF
echo "✅ Shard 2 инициализирован"

###
# Ожидание инициализации реплик
###
echo "⏳ Ожидание 15 секунд инициализации Replica Sets..."
sleep 15

###
# Добавление шардов в кластер через mongos
###
echo "➕ Добавление шардов в кластер через mongos..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1:27018")
sh.addShard("shard2ReplSet/shard2:27020")
EOF
echo "✅ Шарды добавлены в кластер"

###
# Включение шардирования для БД somedb
###
echo "📀 Включение шардирования для БД somedb..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.enableSharding("somedb")
EOF
echo "✅ Шардирование БД включено"

###
# Создание и шардирование коллекции
###
echo "📁 Создание и шардирование коллекции helloDoc..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
db.createCollection("helloDoc")
sh.shardCollection("somedb.helloDoc", {"_id": "hashed"})
EOF
echo "✅ Коллекция создана и зашардирована"

###
# Наполнение БД тестовыми документами
###
echo "📝 Наполнение БД тестовыми документами (1000 шт)..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({age: i, name: "ly" + i})
}
EOF
echo "✅ Данные добавлены"

###
# Финальная проверка
###
echo "📊 РЕЗУЛЬТАТЫ:"

echo "Общее количество документов в кластере:"
TOTAL=$(docker compose exec -T mongos mongosh --port 27017 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()")
echo "$TOTAL документов"

echo "Количество документов в Shard 1 (порт 27018):"
SHARD1_COUNT=$(docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()")
echo "$SHARD1_COUNT документов"

echo "Количество документов в Shard 2 (порт 27020):"
SHARD2_COUNT=$(docker compose exec -T shard2 mongosh --port 27020 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()")
echo "$SHARD2_COUNT документов"

echo "📈 Распределение: Shard1: $SHARD1_COUNT, Shard2: $SHARD2_COUNT"

echo "✅ Скрипт завершен успешно!"