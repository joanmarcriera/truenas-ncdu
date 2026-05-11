IMAGE ?= truenas-ncdu
TAG ?= dev
SCAN_PATH ?= /mnt

.PHONY: test build run shell

test:
	sh scripts/test.sh

build:
	docker build -t $(IMAGE):$(TAG) .

run:
	docker run --rm -it \
		--network none \
		--read-only \
		--tmpfs /tmp:rw,noexec,nosuid,size=64m \
		--cap-drop ALL \
		--security-opt no-new-privileges \
		-v $(SCAN_PATH):/mnt:ro \
		$(IMAGE):$(TAG)

shell:
	docker run --rm -it \
		--network none \
		--read-only \
		--tmpfs /tmp:rw,noexec,nosuid,size=64m \
		--cap-drop ALL \
		--security-opt no-new-privileges \
		-v $(SCAN_PATH):/mnt:ro \
		$(IMAGE):$(TAG) -- sh
