#!/usr/bin/env bash
# Удаляет корневые коллекции-наследие в Firestore. Приложение использует только users/{uid}/...
# ВНИМАНИЕ: данные в этих коллекциях будут удалены без восстановления.
#
# Требования: Node.js, npm i -g firebase-tools, firebase login
# Запуск из корня репозитория:
#   chmod +x scripts/delete_legacy_firestore_collections.sh
#   ./scripts/delete_legacy_firestore_collections.sh
#
# Проверьте PROJECT_ID перед запуском.

set -euo pipefail
PROJECT_ID="${FIREBASE_PROJECT_ID:-goal-planner-c7cbf}"

COLLECTIONS=(
  tasks
  goals
  habits
  user_balances
  user_rewards
  point_transactions
  action_logs
  periods
  task_periods
  rewards
)

for name in "${COLLECTIONS[@]}"; do
  echo "==> Удаление корневой коллекции: $name (project=$PROJECT_ID)"
  firebase -P "$PROJECT_ID" firestore:delete "$name" --recursive --force || {
    echo "    (пропуск или ошибка для $name — возможно, коллекции уже нет)"
  }
done

echo "Готово. Задеплойте правила: firebase deploy --only firestore --project $PROJECT_ID"
