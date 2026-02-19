FROM nvcr.io/nvidia/cuda:13.1.1-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive

ARG BUILD_APT_PROXY
# Make use of apt-cacher-ng if available
RUN if [ "A${BUILD_APT_PROXY:-}" != "A" ]; then \
        echo "Using APT proxy: ${BUILD_APT_PROXY}"; \
        printf 'Acquire::http::Proxy "%s";\n' "$BUILD_APT_PROXY" > /etc/apt/apt.conf.d/01proxy; \
    fi \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates wget gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

ARG BASE_DOCKER_FROM=nvcr.io/nvidia/cuda:13.1.0-devel-ubuntu24.04

# extended from https://gitlab.com/nvidia/container-images/cuda/-/blob/master/dist/13.1.1/ubuntu2404/devel/cudnn/Dockerfile
# using https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa/ (Arm Server Base System Architecture)
ENV NV_CUDNN_VERSION=9.17.1.4-1
ENV NV_CUDNN_PACKAGE_NAME=libcudnn9-cuda-13
ENV NV_CUDNN_PACKAGE=libcudnn9-cuda-13=${NV_CUDNN_VERSION}
ENV NV_CUDNN_PACKAGE_DEV=libcudnn9-dev-cuda-13=${NV_CUDNN_VERSION}
ENV NV_CUDNN_PACKAGE_DEV_HEADERS=libcudnn9-headers-cuda-13=${NV_CUDNN_VERSION}

LABEL com.nvidia.cudnn.version="${NV_CUDNN_VERSION}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ${NV_CUDNN_PACKAGE} \
    ${NV_CUDNN_PACKAGE_DEV} \
    ${NV_CUDNN_PACKAGE_DEV_HEADERS} \
    && apt-mark hold ${NV_CUDNN_PACKAGE_NAME} \
    && apt-get clean
