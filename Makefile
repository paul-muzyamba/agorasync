.PHONY: setup infra-up infra-down migrate dev test clean

setup:
	npm install
	cd packages/database && npm run generate

infra-up:
	docker-compose -f infra/docker-compose.yml up -d

infra-down:
	docker-compose -f infra/docker-compose.yml down

migrate:
	cd packages/database && npm run migrate

dev:
	npm run dev

test:
	npm run test

clean:
	docker-compose -f infra/docker-compose.yml down -v
	rm -rf node_modules apps/*/node_modules packages/*/node_modules
	rm -rf pg_data redis_data
