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
  members: [
  {_id: 0, host: "configsrv1:27019"},
  {_id: 1, host: "configsrv2:27019"},
  {_id: 2, host: "configsrv3:27019"}
  ]})
EOF
echo "✅ Config Server инициализирован"

###
# Инициализация Replica Set для Shard 1
###
echo "🔧 Инициализация Shard 1 (shard11:27018)..."
docker compose exec -T shard11 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet", 
  members: [
  {_id: 0, host: "shard11:27018"},
  {_id: 1, host: "shard12:27018"},
  {_id: 2, host: "shard13:27018"}
  ]})
EOF
echo "✅ Shard 1 инициализирован"

###
# Инициализация Replica Set для Shard 2
###
echo "🔧 Инициализация Shard 2 (shard21:27020)..."
docker compose exec -T shard21 mongosh --port 27020 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet", 
  members: [
  {_id: 0, host: "shard21:27020"},
  {_id: 1, host: "shard22:27020"},
  {_id: 2, host: "shard23:27020"}
  ]})
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
sh.addShard("shard1ReplSet/shard11:27018")
sh.addShard("shard2ReplSet/shard21:27020")
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
# Проверка общего количества документов
###
echo "Общее количество документов:"
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

###
# Проверка распределения документов по шардам
###
echo "Количество документов в shard11:"
docker compose exec -T shard11 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Количество документов в shard12:"
docker compose exec -T shard12 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Количество документов в shard13:"
docker compose exec -T shard13 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Количество документов в shard21:"
docker compose exec -T shard21 mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Количество документов в shard22:"
docker compose exec -T shard22 mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "Количество документов в shard23:"
docker compose exec -T shard23 mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
