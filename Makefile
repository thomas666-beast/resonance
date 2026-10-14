CARTON = carton exec --

.PHONY: help migrate test daemon routes

help:
	@echo "make migrate     - apply DB migrations"
	@echo "make down N=3    - migrate down to N"
	@echo "make test        - run test suite"
	@echo "make daemon      - start dev server"
	@echo "make routes      - list HTTP routes"

migrate:
	$(CARTON) ./script/migrate up

down:
	$(CARTON) ./script/migrate down $(N)

test:
	$(CARTON) prove -l t/

daemon:
	$(CARTON) ./bin/resonance daemon --listen http://127.0.0.1:3000

routes:
	$(CARTON) ./bin/resonance routes
