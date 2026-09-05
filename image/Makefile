IMAGE := logicoar/coder-dev
VERSION ?= 0.1.1

build:
	sudo docker build \
		--platform linux/amd64 \
		-t $(IMAGE):$(VERSION) \
		-t $(IMAGE):latest \
		.

push: build
	sudo docker push $(IMAGE):$(VERSION)
	sudo docker push $(IMAGE):latest
