IMAGE := janoamaral/coder-dev
VERSION ?= 0.1.0

build:
	docker build \
		--platform linux/amd64 \
		-t $(IMAGE):$(VERSION) \
		-t $(IMAGE):latest \
		.

push: build
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):latest
