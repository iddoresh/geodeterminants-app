#!/usr/bin/env bash
set -e

COMPOSE_CMD=""
PORT=3838

check_docker() {
  if ! command -v docker &>/dev/null; then
    echo ""
    echo "Docker is not installed."
    echo "Please install Docker Desktop first:"
    echo "  Mac:     https://docs.docker.com/desktop/install/mac-install/"
    echo "  Windows: https://docs.docker.com/desktop/install/windows-install/"
    echo "  Linux:   https://docs.docker.com/desktop/install/linux-install/"
    echo ""
    exit 1
  fi

  if ! docker info &>/dev/null; then
    echo ""
    echo "Docker is installed but not running."
    echo "Please start Docker Desktop and try again."
    echo ""
    exit 1
  fi
}

find_compose() {
  if docker compose version &>/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
  elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
  else
    echo ""
    echo "Docker Compose not found. Please update Docker Desktop to the latest version."
    echo "  https://docs.docker.com/desktop/"
    echo ""
    exit 1
  fi
}

wait_for_app() {
  echo "Waiting for the app to start..."
  local attempts=0
  while ! curl -sf "http://localhost:${PORT}" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 60 ]; then
      echo ""
      echo "App did not start within 60 seconds."
      echo "Check logs with: docker compose logs"
      exit 1
    fi
    sleep 2
  done
}

open_browser() {
  local url="http://localhost:${PORT}"
  echo "Opening $url ..."
  if command -v xdg-open &>/dev/null; then
    xdg-open "$url"
  elif command -v open &>/dev/null; then
    open "$url"
  elif command -v start &>/dev/null; then
    start "$url"
  else
    echo "Open this URL in your browser: $url"
  fi
}

main() {
  echo ""
  echo "Geodeterminants — SDOH Data Enrichment"
  echo "======================================="
  echo ""

  check_docker
  find_compose

  echo "Building and starting the app (this may take a few minutes the first time)..."
  echo ""

  $COMPOSE_CMD up -d --build

  wait_for_app

  echo ""
  echo "[OK] App is running at http://localhost:${PORT}"
  echo ""
  echo "To stop the app:  docker compose down"
  echo "To view logs:     docker compose logs -f"
  echo ""

  open_browser
}

main
