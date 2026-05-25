.PHONY: setup backfill airflow-up airflow-down clean

setup:
	python scripts/backfill.py

backfill:
	python scripts/backfill.py

airflow-up:
	docker compose up -d

airflow-down:
	docker compose down

airflow-logs:
	docker compose logs -f airflow

clean:
	docker compose down -v
	rm -rf __pycache__ .pytest_cache
