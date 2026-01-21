---
name: kubernetes-expert
version: 3.0.0
level: 3
category: devops
description: Comprehensive Kubernetes orchestration specialist
author: Ahmed Adel Bakr Alderai
updated: 2026-01-21
tags:
  - kubernetes
  - k8s
  - container-orchestration
  - helm
  - gitops
  - cloud-native
capabilities:
  - manifest-generation
  - deployment-strategies
  - service-networking
  - security-policies
  - resource-management
  - autoscaling
  - helm-charts
  - operators-crds
  - troubleshooting
dependencies:
  - docker-expert
  - terraform-expert
  - monitoring-expert
mcp_servers:
  - filesystem
  - git
triggers:
  - "kubernetes"
  - "k8s"
  - "kubectl"
  - "helm"
  - "pod"
  - "deployment"
  - "service"
  - "ingress"
  - "configmap"
  - "secret"
  - "namespace"
  - "hpa"
  - "pdb"
  - "statefulset"
  - "daemonset"
context_budget: 60000
output_budget: 15000
---

# Kubernetes Expert Agent

Comprehensive Kubernetes orchestration specialist with deep expertise in container orchestration, cluster management, deployment strategies, and cloud-native best practices. This agent handles everything from basic manifest creation to advanced operator development and production troubleshooting.

## Arguments

- `$ARGUMENTS` - Kubernetes task, resource type, or troubleshooting scenario

## Invoke Agent

```
Use the Task tool with subagent_type="kubernetes-expert" to:

1. Create and optimize K8s manifests
2. Design deployment strategies (rolling, blue-green, canary)
3. Configure services, ingress, and networking
4. Manage ConfigMaps and Secrets securely
5. Implement RBAC and security policies
6. Set up resource limits and autoscaling
7. Develop Helm charts and operators
8. Debug and troubleshoot cluster issues

Task: $ARGUMENTS
```

---

## Core Kubernetes Resources

### Deployment Manifest (Production-Ready)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: myplatform
    app.kubernetes.io/managed-by: helm
  annotations:
    kubernetes.io/change-cause: "Initial deployment"
spec:
  replicas: 3
  revisionHistoryLimit: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: myapp
  template:
    metadata:
      labels:
        app.kubernetes.io/name: myapp
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: myapp-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: myapp
                topologyKey: kubernetes.io/hostname
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: myapp
      containers:
        - name: myapp
          image: myregistry.io/myapp:1.0.0
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 3000
              protocol: TCP
            - name: metrics
              containerPort: 9090
              protocol: TCP
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
              ephemeral-storage: "100Mi"
            limits:
              memory: "512Mi"
              cpu: "500m"
              ephemeral-storage: "500Mi"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          livenessProbe:
            httpGet:
              path: /health/live
              port: http
            initialDelaySeconds: 15
            periodSeconds: 20
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            successThreshold: 1
            failureThreshold: 3
          startupProbe:
            httpGet:
              path: /health/startup
              port: http
            initialDelaySeconds: 0
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 30
          env:
            - name: NODE_ENV
              value: "production"
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: myapp-secrets
                  key: database-url
            - name: REDIS_HOST
              valueFrom:
                configMapKeyRef:
                  name: myapp-config
                  key: redis-host
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/cache
            - name: config
              mountPath: /app/config
              readOnly: true
      volumes:
        - name: tmp
          emptyDir:
            sizeLimit: 100Mi
        - name: cache
          emptyDir:
            sizeLimit: 500Mi
        - name: config
          configMap:
            name: myapp-config
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      restartPolicy: Always
```

### StatefulSet (Stateful Workloads)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: database
spec:
  serviceName: postgres-headless
  replicas: 3
  podManagementPolicy: OrderedReady
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        fsGroup: 999
      initContainers:
        - name: init-permissions
          image: busybox:1.36
          command: ["sh", "-c", "chown -R 999:999 /var/lib/postgresql/data"]
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
          securityContext:
            runAsUser: 0
            runAsNonRoot: false
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
            - name: postgres
              containerPort: 5432
          env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secrets
                  key: password
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          resources:
            requests:
              memory: "1Gi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "2000m"
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
          livenessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - postgres
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - postgres
            initialDelaySeconds: 5
            periodSeconds: 5
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 100Gi
```

### DaemonSet (Node-Level Workloads)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: node-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9100"
    spec:
      hostNetwork: true
      hostPID: true
      tolerations:
        - operator: Exists
      containers:
        - name: node-exporter
          image: prom/node-exporter:v1.7.0
          args:
            - --path.procfs=/host/proc
            - --path.sysfs=/host/sys
            - --path.rootfs=/host/root
            - --collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+)($|/)
          ports:
            - name: metrics
              containerPort: 9100
          resources:
            requests:
              memory: "50Mi"
              cpu: "50m"
            limits:
              memory: "100Mi"
              cpu: "100m"
          volumeMounts:
            - name: proc
              mountPath: /host/proc
              readOnly: true
            - name: sys
              mountPath: /host/sys
              readOnly: true
            - name: root
              mountPath: /host/root
              readOnly: true
      volumes:
        - name: proc
          hostPath:
            path: /proc
        - name: sys
          hostPath:
            path: /sys
        - name: root
          hostPath:
            path: /
```

---

## Deployment Strategies

### 1. Rolling Update (Default)

```yaml
# Gradual replacement of pods
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25% # Max pods above desired
      maxUnavailable: 25% # Max pods below desired
```

**Use when:**

- Zero-downtime updates required
- Gradual rollout acceptable
- Rollback capability needed

### 2. Blue-Green Deployment

```yaml
# Two identical environments, switch traffic atomically
---
# Blue (current production)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-blue
  labels:
    app: myapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
        - name: myapp
          image: myapp:1.0.0
---
# Green (new version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-green
  labels:
    app: myapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
        - name: myapp
          image: myapp:2.0.0
---
# Service (switch selector to change versions)
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
    version: blue # Change to 'green' to switch
  ports:
    - port: 80
      targetPort: 3000
```

**Switch command:**

```bash
kubectl patch service myapp -p '{"spec":{"selector":{"version":"green"}}}'
```

### 3. Canary Deployment

```yaml
# Route percentage of traffic to new version
---
# Stable (90% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: myapp
      track: stable
  template:
    metadata:
      labels:
        app: myapp
        track: stable
    spec:
      containers:
        - name: myapp
          image: myapp:1.0.0
---
# Canary (10% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      track: canary
  template:
    metadata:
      labels:
        app: myapp
        track: canary
    spec:
      containers:
        - name: myapp
          image: myapp:2.0.0
---
# Service (routes to both based on replica count)
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp # Matches both stable and canary
  ports:
    - port: 80
      targetPort: 3000
```

### 4. Canary with Istio (Precise Traffic Control)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
    - myapp
  http:
    - route:
        - destination:
            host: myapp
            subset: stable
          weight: 90
        - destination:
            host: myapp
            subset: canary
          weight: 10
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: myapp
spec:
  host: myapp
  subsets:
    - name: stable
      labels:
        track: stable
    - name: canary
      labels:
        track: canary
```

### 5. Argo Rollouts (Progressive Delivery)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: { duration: 5m }
        - setWeight: 30
        - pause: { duration: 5m }
        - setWeight: 50
        - pause: { duration: 5m }
        - setWeight: 80
        - pause: { duration: 5m }
      analysis:
        templates:
          - templateName: success-rate
        startingStep: 1
        args:
          - name: service-name
            value: myapp
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:2.0.0
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 1m
      successCondition: result[0] >= 0.95
      failureCondition: result[0] < 0.90
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}",status=~"2.."}[5m])) /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))
```

---

## Service and Networking

### Service Types

```yaml
# ClusterIP (internal only)
apiVersion: v1
kind: Service
metadata:
  name: myapp-internal
spec:
  type: ClusterIP
  clusterIP: None # Headless for StatefulSets
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 3000
---
# NodePort (expose on node IPs)
apiVersion: v1
kind: Service
metadata:
  name: myapp-nodeport
spec:
  type: NodePort
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 3000
      nodePort: 30080 # Range: 30000-32767
---
# LoadBalancer (cloud provider LB)
apiVersion: v1
kind: Service
metadata:
  name: myapp-lb
  annotations:
    # AWS NLB
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    # GCP
    cloud.google.com/load-balancer-type: "Internal"
spec:
  type: LoadBalancer
  loadBalancerSourceRanges:
    - 10.0.0.0/8
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 3000
---
# ExternalName (DNS alias)
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.external-provider.com
```

### Ingress (HTTP/HTTPS Routing)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    # NGINX Ingress Controller
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-burst-multiplier: "5"
    # Cert-Manager
    cert-manager.io/cluster-issuer: letsencrypt-prod
    # AWS ALB Ingress
    # kubernetes.io/ingress.class: alb
    # alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - myapp.example.com
        - api.myapp.example.com
      secretName: myapp-tls
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp-frontend
                port:
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: myapp-backend
                port:
                  number: 80
    - host: api.myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp-api
                port:
                  number: 80
```

### Gateway API (Next-Gen Ingress)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: myapp-gateway
  namespace: gateway-system
spec:
  gatewayClassName: istio
  listeners:
    - name: https
      port: 443
      protocol: HTTPS
      hostname: "*.example.com"
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-tls
            kind: Secret
      allowedRoutes:
        namespaces:
          from: All
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp-route
spec:
  parentRefs:
    - name: myapp-gateway
      namespace: gateway-system
  hostnames:
    - "myapp.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: myapp-api
          port: 80
          weight: 90
        - name: myapp-api-canary
          port: 80
          weight: 10
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: myapp-frontend
          port: 80
```

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: myapp-network-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
      ports:
        - protocol: TCP
          port: 3000
    # Allow from monitoring
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - protocol: TCP
          port: 9090
    # Allow from same app
    - from:
        - podSelector:
            matchLabels:
              app: myapp
  egress:
    # Allow DNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
    # Allow database
    - to:
        - namespaceSelector:
            matchLabels:
              name: database
          podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    # Allow external HTTPS
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 192.168.0.0/16
              - 172.16.0.0/12
      ports:
        - protocol: TCP
          port: 443
```

---

## ConfigMaps and Secrets

### ConfigMap Patterns

```yaml
# Literal values
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: production
data:
  LOG_LEVEL: "info"
  CACHE_TTL: "3600"
  FEATURE_FLAGS: |
    {
      "newUI": true,
      "betaFeatures": false,
      "maintenanceMode": false
    }
---
# From file (create with kubectl)
# kubectl create configmap nginx-config --from-file=nginx.conf

# Binary data (base64 encoded automatically)
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-binary
binaryData:
  logo.png: <base64-encoded-data>
```

### Secrets Management

```yaml
# Generic secret
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
  namespace: production
type: Opaque
stringData: # Use stringData for plain text (auto-encoded)
  database-url: "postgres://user:pass@host:5432/db"
  api-key: "sk-live-xxxxx"
data: # Use data for pre-encoded values
  jwt-secret: c2VjcmV0LWtleS1oZXJl # base64
---
# Docker registry secret
apiVersion: v1
kind: Secret
metadata:
  name: regcred
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
---
# TLS secret
apiVersion: v1
kind: Secret
metadata:
  name: myapp-tls
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
---
# Service account token (auto-mounted)
apiVersion: v1
kind: Secret
metadata:
  name: myapp-sa-token
  annotations:
    kubernetes.io/service-account.name: myapp-sa
type: kubernetes.io/service-account-token
```

### External Secrets Operator

```yaml
# SecretStore (cluster-wide)
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
---
# ExternalSecret (pulls from AWS)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: myapp-external-secrets
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: myapp-secrets
    creationPolicy: Owner
  data:
    - secretKey: database-url
      remoteRef:
        key: production/myapp/database
        property: url
    - secretKey: api-key
      remoteRef:
        key: production/myapp/api
        property: key
```

### Sealed Secrets (GitOps-Safe)

```yaml
# Sealed secret (encrypted, safe to commit)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: myapp-secrets
  namespace: production
spec:
  encryptedData:
    database-url: AgBy3i4OJSWK+PiTySYZZA9...
    api-key: AgBy8o2PJSWK+PiTySYZZA9...
  template:
    metadata:
      name: myapp-secrets
    type: Opaque
```

**Create sealed secret:**

```bash
kubectl create secret generic myapp-secrets \
  --from-literal=database-url='postgres://...' \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > sealed-secret.yaml
```

---

## RBAC and Security Policies

### ServiceAccount with RBAC

```yaml
# ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp-sa
  namespace: production
automountServiceAccountToken: false
---
# Role (namespaced)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: myapp-role
  namespace: production
rules:
  # Read ConfigMaps
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
  # Read/Write own secrets
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["myapp-secrets"]
    verbs: ["get", "update"]
  # Read pods for health checks
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: myapp-role-binding
  namespace: production
subjects:
  - kind: ServiceAccount
    name: myapp-sa
    namespace: production
roleRef:
  kind: Role
  name: myapp-role
  apiGroup: rbac.authorization.k8s.io
---
# ClusterRole (cluster-wide)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: myapp-cluster-role
rules:
  # Read nodes for scheduling info
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list"]
  # Read namespaces
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list"]
---
# ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: myapp-cluster-role-binding
subjects:
  - kind: ServiceAccount
    name: myapp-sa
    namespace: production
roleRef:
  kind: ClusterRole
  name: myapp-cluster-role
  apiGroup: rbac.authorization.k8s.io
```

### Pod Security Standards

```yaml
# Namespace with Pod Security Standards
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
# Pod Security Policy (deprecated, use PSS)
# Keeping for legacy clusters
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - "configMap"
    - "emptyDir"
    - "projected"
    - "secret"
    - "downwardAPI"
    - "persistentVolumeClaim"
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: MustRunAsNonRoot
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: MustRunAs
    ranges:
      - min: 1
        max: 65535
  fsGroup:
    rule: MustRunAs
    ranges:
      - min: 1
        max: 65535
  readOnlyRootFilesystem: true
```

### Kyverno Policies

```yaml
# Require resource limits
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-limits
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "CPU and memory limits are required."
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
---
# Require non-root
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-non-root
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-non-root
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Running as root is not allowed."
        pattern:
          spec:
            securityContext:
              runAsNonRoot: true
            containers:
              - securityContext:
                  runAsNonRoot: true
                  allowPrivilegeEscalation: false
---
# Mutate: Add default labels
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-labels
spec:
  rules:
    - name: add-labels
      match:
        any:
          - resources:
              kinds:
                - Pod
                - Deployment
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(app.kubernetes.io/managed-by): kyverno
              +(environment): "{{request.namespace}}"
```

---

## Resource Management

### Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    # Compute resources
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    # Object counts
    pods: "100"
    services: "50"
    secrets: "100"
    configmaps: "100"
    persistentvolumeclaims: "50"
    # Storage
    requests.storage: 1Ti
    # Priority classes
    count/deployments.apps: "50"
    count/statefulsets.apps: "10"
---
# Scoped quota for best-effort pods
apiVersion: v1
kind: ResourceQuota
metadata:
  name: best-effort-quota
  namespace: development
spec:
  hard:
    pods: "20"
  scopeSelector:
    matchExpressions:
      - operator: In
        scopeName: PriorityClass
        values:
          - low-priority
```

### LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
    # Default for containers
    - type: Container
      default:
        cpu: "500m"
        memory: "512Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      min:
        cpu: "50m"
        memory: "64Mi"
      max:
        cpu: "4"
        memory: "8Gi"
      maxLimitRequestRatio:
        cpu: "10"
        memory: "4"
    # Limits for pods
    - type: Pod
      max:
        cpu: "8"
        memory: "16Gi"
    # PVC limits
    - type: PersistentVolumeClaim
      min:
        storage: "1Gi"
      max:
        storage: "100Gi"
```

### Priority Classes

```yaml
# System critical (do not evict)
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: system-critical
value: 1000000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "Critical system components"
---
# High priority production
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "Production workloads"
---
# Default priority
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: default-priority
value: 0
globalDefault: true
preemptionPolicy: PreemptLowerPriority
description: "Default priority class"
---
# Low priority (preemptable)
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: -1000
globalDefault: false
preemptionPolicy: Never
description: "Batch jobs, can be preempted"
```

### Pod Disruption Budget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
  namespace: production
spec:
  # Either minAvailable or maxUnavailable, not both
  minAvailable: 2
  # maxUnavailable: 1
  # maxUnavailable: 25%
  selector:
    matchLabels:
      app: myapp
  unhealthyPodEvictionPolicy: IfHealthyBudget
```

---

## Horizontal Pod Autoscaling

### HPA v2 (Full API)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 3
  maxReplicas: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
        - type: Pods
          value: 2
          periodSeconds: 60
      selectPolicy: Min
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
        - type: Pods
          value: 4
          periodSeconds: 15
      selectPolicy: Max
  metrics:
    # CPU utilization
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    # Memory utilization
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
    # Custom metrics (Prometheus)
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "100"
    # External metrics
    - type: External
      external:
        metric:
          name: queue_messages_ready
          selector:
            matchLabels:
              queue: myapp-queue
        target:
          type: AverageValue
          averageValue: "30"
```

### Vertical Pod Autoscaler

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  updatePolicy:
    updateMode: "Auto" # Off, Initial, Recreate, Auto
    minReplicas: 2
  resourcePolicy:
    containerPolicies:
      - containerName: myapp
        minAllowed:
          cpu: "100m"
          memory: "128Mi"
        maxAllowed:
          cpu: "4"
          memory: "8Gi"
        controlledResources: ["cpu", "memory"]
        controlledValues: RequestsAndLimits
```

### KEDA (Event-Driven Autoscaling)

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: myapp-scaledobject
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicaCount: 1
  maxReplicaCount: 100
  pollingInterval: 30
  cooldownPeriod: 300
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 300
  triggers:
    # RabbitMQ queue
    - type: rabbitmq
      metadata:
        host: amqp://rabbitmq.default.svc.cluster.local
        queueName: myapp-queue
        mode: QueueLength
        value: "100"
    # Prometheus
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        metricName: http_requests_total
        threshold: "100"
        query: sum(rate(http_requests_total{service="myapp"}[2m]))
    # Cron schedule
    - type: cron
      metadata:
        timezone: America/New_York
        start: 0 8 * * 1-5
        end: 0 18 * * 1-5
        desiredReplicas: "10"
```

---

## Helm Chart Development

### Chart Structure

```
myapp-chart/
├── Chart.yaml
├── Chart.lock
├── values.yaml
├── values-production.yaml
├── values-staging.yaml
├── .helmignore
├── templates/
│   ├── _helpers.tpl
│   ├── NOTES.txt
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   ├── serviceaccount.yaml
│   ├── rbac.yaml
│   └── tests/
│       └── test-connection.yaml
├── charts/
│   └── (subcharts)
└── crds/
    └── (custom resources)
```

### Chart.yaml

```yaml
apiVersion: v2
name: myapp
description: My Application Helm Chart
type: application
version: 1.0.0
appVersion: "2.0.0"
kubeVersion: ">=1.25.0"
keywords:
  - myapp
  - backend
  - api
home: https://github.com/myorg/myapp
sources:
  - https://github.com/myorg/myapp
maintainers:
  - name: Ahmed Adel Bakr Alderai
    email: ahmed@example.com
dependencies:
  - name: postgresql
    version: "13.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
  - name: redis
    version: "18.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled
annotations:
  artifacthub.io/license: MIT
  artifacthub.io/operator: "false"
```

### values.yaml

```yaml
# Default values for myapp
replicaCount: 3

image:
  repository: myregistry.io/myapp
  pullPolicy: IfNotPresent
  tag: "" # Defaults to chart appVersion

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""
  automountServiceAccountToken: false

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL

service:
  type: ClusterIP
  port: 80
  targetPort: 3000

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: myapp-tls
      hosts:
        - myapp.example.com

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 50
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

pdb:
  enabled: true
  minAvailable: 2

nodeSelector: {}

tolerations: []

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: myapp
          topologyKey: kubernetes.io/hostname

# Application configuration
config:
  logLevel: info
  cacheTTL: 3600
  featureFlags:
    newUI: true
    betaFeatures: false

# Secrets (use external-secrets in production)
secrets:
  create: true
  databaseUrl: ""
  apiKey: ""

# Subcharts
postgresql:
  enabled: true
  auth:
    database: myapp
    username: myapp

redis:
  enabled: false
  architecture: standalone
```

### templates/\_helpers.tpl

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "myapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "myapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "myapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "myapp.labels" -}}
helm.sh/chart: {{ include "myapp.chart" . }}
{{ include "myapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "myapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "myapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create image reference
*/}}
{{- define "myapp.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}
```

### templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "myapp.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: {{ include "myapp.image" . }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /health/live
              port: http
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          env:
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: {{ include "myapp.fullname" . }}
                  key: LOG_LEVEL
            {{- if .Values.secrets.databaseUrl }}
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: {{ include "myapp.fullname" . }}
                  key: database-url
            {{- end }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

### Helm Commands

```bash
# Create new chart
helm create myapp-chart

# Lint chart
helm lint ./myapp-chart

# Template (dry-run)
helm template myapp ./myapp-chart -f values-production.yaml

# Install/upgrade
helm upgrade --install myapp ./myapp-chart \
  --namespace production \
  --create-namespace \
  -f values-production.yaml \
  --set image.tag=1.2.3 \
  --atomic \
  --timeout 10m

# Rollback
helm rollback myapp 1 --namespace production

# Package and push
helm package ./myapp-chart
helm push myapp-chart-1.0.0.tgz oci://myregistry.io/charts
```

---

## Operators and Custom Resources

### Custom Resource Definition (CRD)

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: webapps.myapp.io
spec:
  group: myapp.io
  names:
    kind: WebApp
    listKind: WebAppList
    plural: webapps
    singular: webapp
    shortNames:
      - wa
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      subresources:
        status: {}
        scale:
          specReplicasPath: .spec.replicas
          statusReplicasPath: .status.replicas
      additionalPrinterColumns:
        - name: Replicas
          type: integer
          jsonPath: .spec.replicas
        - name: Available
          type: integer
          jsonPath: .status.availableReplicas
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
      schema:
        openAPIV3Schema:
          type: object
          required:
            - spec
          properties:
            spec:
              type: object
              required:
                - image
              properties:
                image:
                  type: string
                  pattern: '^[\w.-]+(/[\w.-]+)*(:\S+)?$'
                replicas:
                  type: integer
                  minimum: 1
                  maximum: 100
                  default: 1
                port:
                  type: integer
                  minimum: 1
                  maximum: 65535
                  default: 8080
                resources:
                  type: object
                  properties:
                    requests:
                      type: object
                      properties:
                        cpu:
                          type: string
                        memory:
                          type: string
                    limits:
                      type: object
                      properties:
                        cpu:
                          type: string
                        memory:
                          type: string
                ingress:
                  type: object
                  properties:
                    enabled:
                      type: boolean
                      default: false
                    host:
                      type: string
                    tls:
                      type: boolean
                      default: true
            status:
              type: object
              properties:
                replicas:
                  type: integer
                availableReplicas:
                  type: integer
                conditions:
                  type: array
                  items:
                    type: object
                    properties:
                      type:
                        type: string
                      status:
                        type: string
                      lastTransitionTime:
                        type: string
                        format: date-time
                      reason:
                        type: string
                      message:
                        type: string
```

### Custom Resource Instance

```yaml
apiVersion: myapp.io/v1
kind: WebApp
metadata:
  name: frontend
  namespace: production
spec:
  image: myregistry.io/frontend:1.0.0
  replicas: 3
  port: 3000
  resources:
    requests:
      cpu: "100m"
      memory: "128Mi"
    limits:
      cpu: "500m"
      memory: "512Mi"
  ingress:
    enabled: true
    host: frontend.example.com
    tls: true
```

### Operator Reconciliation (Go Skeleton)

```go
// Reconcile function (controller-runtime)
func (r *WebAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // Fetch the WebApp instance
    webapp := &myappv1.WebApp{}
    if err := r.Get(ctx, req.NamespacedName, webapp); err != nil {
        if errors.IsNotFound(err) {
            return ctrl.Result{}, nil
        }
        return ctrl.Result{}, err
    }

    // Create or update Deployment
    deployment := r.deploymentForWebApp(webapp)
    if err := controllerutil.SetControllerReference(webapp, deployment, r.Scheme); err != nil {
        return ctrl.Result{}, err
    }

    found := &appsv1.Deployment{}
    err := r.Get(ctx, types.NamespacedName{Name: deployment.Name, Namespace: deployment.Namespace}, found)
    if err != nil && errors.IsNotFound(err) {
        log.Info("Creating Deployment", "name", deployment.Name)
        if err := r.Create(ctx, deployment); err != nil {
            return ctrl.Result{}, err
        }
        return ctrl.Result{Requeue: true}, nil
    }

    // Update if spec changed
    if !reflect.DeepEqual(deployment.Spec, found.Spec) {
        found.Spec = deployment.Spec
        if err := r.Update(ctx, found); err != nil {
            return ctrl.Result{}, err
        }
    }

    // Update status
    webapp.Status.Replicas = found.Status.Replicas
    webapp.Status.AvailableReplicas = found.Status.AvailableReplicas
    if err := r.Status().Update(ctx, webapp); err != nil {
        return ctrl.Result{}, err
    }

    return ctrl.Result{}, nil
}
```

---

## Debugging and Troubleshooting

### Essential kubectl Commands

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes -o wide
kubectl top nodes
kubectl describe node <node-name>

# Namespace operations
kubectl get namespaces
kubectl config set-context --current --namespace=production

# Pod debugging
kubectl get pods -o wide --show-labels
kubectl describe pod <pod-name>
kubectl logs <pod-name> -c <container> --tail=100 -f
kubectl logs <pod-name> --previous  # Previous container logs
kubectl exec -it <pod-name> -- /bin/sh
kubectl port-forward <pod-name> 8080:3000

# Events (sorted by time)
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector type=Warning

# Resource usage
kubectl top pods --containers
kubectl top pods --sort-by=memory

# Network debugging
kubectl run debug --image=nicolaka/netshoot --rm -it -- bash
kubectl run curl --image=curlimages/curl --rm -it -- sh

# API resources
kubectl api-resources
kubectl explain deployment.spec.strategy
```

### Common Issues and Solutions

```yaml
# Issue: Pod stuck in Pending
# Diagnosis:
kubectl describe pod <pod-name> | grep -A 10 Events
kubectl get events --field-selector involvedObject.name=<pod-name>

# Common causes:
# - Insufficient resources: Check node capacity, resource requests
# - Node selector/affinity: Verify labels match
# - PVC not bound: Check PV availability
# - Image pull errors: Check imagePullSecrets

---
# Issue: Pod in CrashLoopBackOff
# Diagnosis:
kubectl logs <pod-name> --previous
kubectl describe pod <pod-name>

# Common causes:
# - Application crash: Check logs, liveness probe
# - Missing config/secrets: Verify mounts
# - Permission denied: Check securityContext
# - OOMKilled: Increase memory limits

---
# Issue: Service not reachable
# Diagnosis:
kubectl get endpoints <service-name>
kubectl describe service <service-name>

# Debug from within cluster:
kubectl run debug --image=nicolaka/netshoot --rm -it -- \
  curl -v http://<service-name>.<namespace>.svc.cluster.local

# Common causes:
# - Selector mismatch: Verify labels
# - No ready pods: Check pod status
# - NetworkPolicy blocking: Review policies
# - Wrong port: Check targetPort

---
# Issue: Ingress not working
# Diagnosis:
kubectl describe ingress <ingress-name>
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Common causes:
# - Ingress class missing: Add ingressClassName
# - TLS secret missing: Create secret
# - Backend service unavailable: Check service
# - DNS not configured: Verify external DNS
```

### Debug Containers (Ephemeral)

```bash
# Add debug container to running pod
kubectl debug <pod-name> -it --image=nicolaka/netshoot --target=<container>

# Debug with copy (creates new pod)
kubectl debug <pod-name> -it --copy-to=debug-pod --container=debug \
  --image=busybox -- sh

# Debug node
kubectl debug node/<node-name> -it --image=ubuntu
```

### Resource Analysis Scripts

```bash
#!/bin/bash
# k8s-health-check.sh - Comprehensive cluster health check

echo "=== Node Status ==="
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,STATUS:.status.conditions[-1].type,CPU:.status.capacity.cpu,MEM:.status.capacity.memory'

echo -e "\n=== Pod Issues ==="
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount'

echo -e "\n=== Recent Warnings ==="
kubectl get events --all-namespaces --field-selector type=Warning \
  --sort-by='.lastTimestamp' | tail -20

echo -e "\n=== Resource Usage ==="
kubectl top nodes
echo ""
kubectl top pods --all-namespaces --sort-by=memory | head -10

echo -e "\n=== PVC Status ==="
kubectl get pvc --all-namespaces -o custom-columns=\
'NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,STORAGE:.spec.resources.requests.storage'

echo -e "\n=== Certificate Expiry ==="
kubectl get certificates --all-namespaces -o custom-columns=\
'NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter'
```

### Troubleshooting Decision Tree

```
Pod Not Running
├── Pending
│   ├── Insufficient resources → Scale cluster or reduce requests
│   ├── Node affinity/selector → Fix labels or constraints
│   ├── PVC Pending → Check StorageClass and PV
│   └── Taints/Tolerations → Add tolerations
├── ImagePullBackOff
│   ├── Wrong image name → Fix image reference
│   ├── Private registry → Add imagePullSecrets
│   └── Quota exceeded → Increase registry quota
├── CrashLoopBackOff
│   ├── Check logs → Fix application error
│   ├── Liveness probe failing → Adjust probe or fix health endpoint
│   ├── OOMKilled → Increase memory limit
│   └── Permission denied → Fix securityContext
├── Error
│   ├── Init container failed → Check init container logs
│   └── Volume mount failed → Verify volume/secret exists
└── Running but not Ready
    └── Readiness probe failing → Fix application or probe config

Service Not Working
├── No endpoints
│   ├── Selector mismatch → Fix pod labels
│   └── No ready pods → Debug pod issues
├── Endpoints exist but unreachable
│   ├── NetworkPolicy → Check ingress rules
│   ├── Wrong port → Fix targetPort
│   └── Container not listening → Check app binding
└── Intermittent failures
    ├── Pod instability → Check resources/probes
    └── Load balancing issues → Check session affinity
```

---

## GitOps with ArgoCD

### Application Definition

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myapp-deploy.git
    targetRevision: HEAD
    path: overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - Validate=true
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### ApplicationSet (Multi-Cluster)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-set
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: production
            url: https://prod-cluster.example.com
            values:
              replicas: "10"
          - cluster: staging
            url: https://staging-cluster.example.com
            values:
              replicas: "2"
  template:
    metadata:
      name: "myapp-{{cluster}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/myapp-deploy.git
        targetRevision: HEAD
        path: overlays/{{cluster}}
        helm:
          valueFiles:
            - values-{{cluster}}.yaml
          parameters:
            - name: replicas
              value: "{{values.replicas}}"
      destination:
        server: "{{url}}"
        namespace: myapp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

---

## Best Practices Checklist

### Security

- [ ] Non-root containers with read-only filesystem
- [ ] Drop all capabilities, add only required
- [ ] NetworkPolicies for pod-to-pod traffic
- [ ] Secrets from external providers (not in git)
- [ ] RBAC with least privilege
- [ ] Pod Security Standards enforced
- [ ] Image scanning in CI/CD
- [ ] Signed images with admission control

### Reliability

- [ ] Resource requests and limits set
- [ ] Liveness, readiness, and startup probes
- [ ] PodDisruptionBudget for availability
- [ ] Anti-affinity for HA spread
- [ ] Topology spread constraints
- [ ] Graceful shutdown handling
- [ ] Rollback strategy defined
- [ ] Backup and disaster recovery plan

### Observability

- [ ] Prometheus metrics exposed
- [ ] Structured logging (JSON)
- [ ] Distributed tracing (OpenTelemetry)
- [ ] Dashboards for key metrics
- [ ] Alerting rules defined
- [ ] Log aggregation configured

### Operations

- [ ] GitOps for deployments
- [ ] Helm charts for packaging
- [ ] CI/CD pipeline with testing
- [ ] Staging environment matching production
- [ ] Runbooks for common issues
- [ ] Capacity planning documented

---

## Quick Reference

| Resource     | Command                                        |
| ------------ | ---------------------------------------------- |
| List all     | `kubectl get all -A`                           |
| Describe     | `kubectl describe <type> <name>`               |
| Logs         | `kubectl logs <pod> -f --tail=100`             |
| Exec         | `kubectl exec -it <pod> -- /bin/sh`            |
| Port-forward | `kubectl port-forward <pod> 8080:3000`         |
| Apply        | `kubectl apply -f manifest.yaml`               |
| Delete       | `kubectl delete -f manifest.yaml`              |
| Scale        | `kubectl scale deployment/<name> --replicas=5` |
| Rollout      | `kubectl rollout status deployment/<name>`     |
| Rollback     | `kubectl rollout undo deployment/<name>`       |

---

## Example Invocations

```bash
# Create production-ready deployment
/agents/devops/kubernetes-expert create deployment for Node.js API with HPA, PDB, and network policies

# Set up blue-green deployment
/agents/devops/kubernetes-expert implement blue-green deployment strategy for myapp

# Debug pod issues
/agents/devops/kubernetes-expert troubleshoot pod stuck in CrashLoopBackOff

# Create Helm chart
/agents/devops/kubernetes-expert create Helm chart for microservice with external secrets

# Configure ingress with TLS
/agents/devops/kubernetes-expert set up NGINX ingress with cert-manager and rate limiting

# Implement RBAC
/agents/devops/kubernetes-expert create RBAC for service account with minimal permissions
```

---

## Related Agents

- `/agents/devops/docker-expert` - Container image building
- `/agents/devops/terraform-expert` - Infrastructure provisioning
- `/agents/devops/monitoring-expert` - Prometheus/Grafana setup
- `/agents/devops/ci-cd-expert` - Pipeline configuration
- `/agents/cloud/gcp-expert` - GKE-specific features
- `/agents/cloud/aws-expert` - EKS-specific features
- `/agents/security/security-expert` - Security hardening

---

**Author:** Ahmed Adel Bakr Alderai
**Version:** 3.0.0
**Last Updated:** 2026-01-21
