[<< home](../README.md)

# Setup Kubernetes Signature Verification via Connaisseur

## Links:
* [Connaisseur](https://github.com/sse-secure-systems/connaisseur)
* [Connaisseur + ACR notes](https://sse-secure-systems.github.io/connaisseur/v2.8.0/validators/notaryv1/#using-azure-container-registry)

## Steps:

1) Prepare helm according connaisseur repository readme
2) Prepare validator, like:
    ```yaml
    name: example_acr
    type: notaryv1
    host: example.azurecr.io
    is_acr: true
    auth:
      // Service Principal creds with Reader role
      username: ''
      password: ''
    trust_roots:
      - name: root
        key: |
          -----BEGIN PUBLIC KEY-----
          registry public key (helper script generates this one)
          -----END PUBLIC KEY-----
    ```
3) Prepare policy, like:
    ```yaml
    pattern: example.azurecr.io/*:*
    validator: example_acr
    with:
      trust_root: root
    ```

---

## Notes:

Latest Helm chart 1.6.0 has a bug with notary and auth.username/auth.password (they don't pasted to the configmap after render). 

You need to remove condition below from helm chart `config.yaml`

```yaml
  {{- $_ := unset $validator "auth" -}}
```
