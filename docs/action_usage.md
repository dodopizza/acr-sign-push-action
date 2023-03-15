[<< home](../README.md)

# How to use the `acr-sign-push-action`

### Requirements:
* If you still haven't key pairs to sign the images, please read "[prepare keys](./prepare_keys.md)" article

### GHA Workflow example

```yaml
name: Signed release

on:
  push:

jobs:
  Build/Sign/Release:
    runs-on: ubuntu-latest
    env:
      image-ref: example.azurecr.io/nginx:latest
    steps:
        // Checkout repo
      - uses: actions/checkout@v3

        // Login to registry
      - uses: docker/login-action@v2
        with:
          // User needs to have at least "AcrPush", "AcrImageSigner" roles
          registry: example.azurecr.io
          username: ${{ secrets.registry_username }}
          password: ${{ secrets.registry_password }}
          
        // Build Dockerfile
      - uses: docker/build-push-action@v4
        with:
          tags: ${{ env.image-ref }}

        // Sign and Push to registry
      - uses: dodopizza/acr-sign-push-action@main
        with:
          image-ref: ${{ env.image-ref }}
          signer-key-id: ${{ secrets.signer_key_id }}
          signer-key: ${{ secrets.signer_key_content_base64 }}
          repository-passphrase: ${{ secrets.repository_passphrase }}
```
