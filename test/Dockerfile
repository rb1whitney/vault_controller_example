FROM alpine
WORKDIR /usr/vault

# Install Prerequisites for running tests
RUN apk add zsh bash git jq unzip wget tree
RUN wget -q https://releases.hashicorp.com/vault/1.4.2/vault_1.4.2_linux_amd64.zip && unzip vault_*_linux_amd64.zip && rm -f vault_*_linux_amd64.zip
RUN git clone https://github.com/bats-core/bats-core.git --quiet && cd bats-core && ./install.sh /usr/vault/bats && rm -rf /usr/vault/bats-core
ENV PATH="/usr/vault:/usr/vault/bats/bin:${PATH}"

# Install Tests
COPY . /usr/vault
RUN chmod 755 test/run-bats.sh
ENTRYPOINT "/usr/vault/test/run-bats.sh"
