### demo-app folder

contains dockerized app that needs 5 seconds for startup, then serves content on 80 port.

gets 2 env params:
 - TEST_VAR
 - TEST_SECRET

---
### docker container
tags:
  - v1 - returns 404

  - v2 - gets vars

docker run --rm -e TEST_VAR=test -p 8080:80 ymuski/helm-demo-app:v2

---
### Helm installing

  - add k8s configs to ~/.kube/config
  - install helm binary
    - mac:
      ```
      mkdir /tmp/helm
      curl -o /tmp/helm/helm-v2.14.3-darwin-amd64.tar.gz https://get.helm.sh/helm-v2.14.3-darwin-amd64.tar.gz
      tar -C /tmp/helm -zxvf /tmp/helm/helm-v2.14.3-darwin-amd64.tar.gz
      mv /tmp/helm/darwin-amd64/helm /usr/local/bin/helm
      rm -rf /tmp/helm
      ```
    - linux:
      ```
      wget -P /tmp/helm https://get.helm.sh/helm-v2.14.3-linux-amd64.tar.gz
      tar -C /tmp/helm -zxvf /tmp/helm/helm-v2.14.3-linux-amd64.tar.gz
      mv /tmp/helm/linux-amd64/helm /usr/local/bin/helm
      rm -rf /tmp/helm
      ```
  - `helm init --service-account tiller --history-max 20 --client-only`

---
### Helm creating chart

- `helm create helm-demo-chart`

- update YOUR_NAME and DOMAIN to actual values.

- edit `values.yaml`
    ```
    image:
      repository: ymuski/helm-demo-app
      tag: v1
    ```
    ```
    ingress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
        # kubernetes.io/tls-acme: "true"
      hosts:
        - host: helm-demo-app-YOUR_NAME.DOMAIN
          paths:
          - /
      tls:
      - secretName: DOMAIN-tls
        hosts:
          - helm-demo-app-YOUR_NAME.DOMAIN
    ```

  - remove livenessProbe and readnessProbe from templates/deployment.yaml

  - deploy #1
    - `helm upgrade --install helm-demo-chart-YOUR_NAME helm-demo-chart/ --debug`
    - `helm status helm-demo-chart-YOUR_NAME`
    - go to ingress url

    Note: without Probes helm and k8s shows OK status on 404 responce.

---
### LivenessProbe and ReadnessProbe
- deployment.yaml
  ```
  spec:
    template:
      spec:
        containers:
          - name:
            livenessProbe:
              {{- toYaml .Values.containers.livenessProbe | nindent 12 }}
            readinessProbe:
              {{- toYaml .Values.containers.readinessProbe | nindent 12 }}
  ```

- values.yaml
  ```
  containers:
    # Indicates whether the Container is running. Ensures that containers are restarted when they fail.
    livenessProbe:
      failureThreshold: 3 #dafault: 3
      initialDelaySeconds: 0 #default 0
      periodSeconds: 10 #dafault: 10
      successThreshold: 1 #dafault: 1
      timeoutSeconds: 1 #dafault: 1
      httpGet:
        path: /
        port: 80

    #  Indicates whether the Container is ready to service requests. Ensures that traffic does not reach a container that is not ready for it.
    readinessProbe:
      failureThreshold: 3
      initialDelaySeconds: 0
      periodSeconds: 10
      successThreshold: 1
      timeoutSeconds: 1
      httpGet:
        path: /
        port: 80
  ```

- deploy #2
- `helm upgrade --install helm-demo-chart-YOUR_NAME helm-demo-chart/ --debug`
- `helm status helm-demo-chart-YOUR_NAME`

  Note: with Probes new pod is not marked as healthy and previous is not terminated.

---
### Fixing 404 issue
- change image tag to v2

  - values.yaml
    ```
    image:
      tag: v2
    ```

- deploy #3
  - `helm upgrade --install helm-demo-chart-YOUR_NAME helm-demo-chart/ --debug`
  - `helm status helm-demo-chart-YOUR_NAME`
  - go to ingress url

  Note: pod startup takes some time, k8s kills prev pod only after the new one is ready (Deployment = RollingUpdate).

---
### Rollback with helm

- deploy #4 (chaged image tag to v1 + rollback + atomic)
  - `helm upgrade --install helm-demo-chart-YOUR_NAME helm-demo-chart/ --debug --set image.tag=v1`
  - `helm status helm-demo-chart-YOUR_NAME`
  - `helm history helm-demo-chart-YOUR_NAME`

  Rollback last one:
  - `helm rollback helm-demo-chart-YOUR_NAME 0`
  - `helm status helm-demo-chart-YOUR_NAME`
  - `helm history helm-demo-chart-YOUR_NAME`

  Use atomic helm param:
  - `helm upgrade --install helm-demo-chart-YOUR_NAME helm-demo-chart/ --debug --set image.tag=v1 --atomic --timeout=15`
  - `helm status helm-demo-chart-YOUR_NAME`
  - `helm history helm-demo-chart-YOUR_NAME`

  Check configuration currently applied, check tag:
  - `helm get helm-demo-chart-YOUR_NAME`

---
### Adding env var

- values.yaml
  ```
  containers:
    env:
      TEST_VAR: "hello_var"
  ```

- deployment.yaml
  ```
  spec:
    template:
      spec:
        containers:
          - name:
            {{- if .Values.containers.env }}
            env:
            {{- range $key, $value := .Values.containers.env }}
              - name: {{ $key }}
                value: {{ $value | quote }}
            {{- end }}
            {{- end }}
  ```

- deploy #5
  - `helm upgrade --install helm-demo-chart-YOUR_NAME helm-demo-chart/ --debug`
  - `helm status helm-demo-chart-YOUR_NAME`
  - go to ingress url

---
### Adding secrets

- secrets.yaml
  ```
  apiVersion: v1
  kind: Secret
  metadata:
    name: {{ include "helm-demo-chart.fullname" . }}
    labels:
  {{ include "helm-demo-chart.labels" . | indent 4 }}
  type: Opaque
  data:
  {{- range $key, $value := .Values.containers.secrets }}
    {{ $key }}: {{ $value | quote }}
  {{- end }}
  ```

- values.yaml
  ```
  containers:
    #echo -n text | base64
    #echo -n dGV4dA== | base64 --decode
    secrets:
      TEST_SECRET: c3VwZXJfc2VjcmV0
  ```

- deployment.yaml
  ```
  spec:
    template:
      metadata:
        labels:
          checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum | trunc 20 }}
  ```
  ```
  spec:
    template:
      spec:
        containers:
          - name:
            envFrom:
            - secretRef:
                name: {{ include "helm-demo-chart.fullname" . }}
  ```

- deploy #6
  - `helm upgrade --install helm-demo-chart-YOUR_NAME helm-demo-chart/ --debug`
  - `helm status helm-demo-chart-YOUR_NAME`
  - go to ingress url

---
### Helm dependencies
- requirements.yaml
  ```
  dependencies:
    - name: mysql
      version: 1.4.0
      repository: "@stable"
  ```
- deploy #7
  - `helm dependency update helm-demo-chart/`
  - `helm upgrade --install helm-demo-chart-YOUR_NAME helm-demo-chart/ --debug --set mysql.persistence.storageClass=local-path,mysql.persistence.size=1Gi`
  - `helm status helm-demo-chart-YOUR_NAME`

---
### Clean up
- `helm del --purge helm-demo-chart-YOUR_NAME`