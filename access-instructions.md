# Accessing the Birthday Tekken API Application

## Getting the Ingress Gateway IP

To access your application, you need to get the IP address of the Istio ingress gateway and set up your hosts file to route the domain to that IP.

```bash
# Get the external IP of the Istio ingress gateway
kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## Update Your Hosts File

Once you have the IP address, add it to your hosts file:

```bash
# On Linux/MacOS
sudo sh -c "echo '<INGRESS-IP> birthday.local' >> /etc/hosts"

# On Windows (run as Administrator)
echo <INGRESS-IP> birthday.local >> C:\Windows\System32\drivers\etc\hosts
```

Replace `<INGRESS-IP>` with the actual IP address you obtained in the previous step.

## Access the Application

After setting up your hosts file, you can access the application by opening a web browser and navigating to:

```
http://birthday.local
```

## Verifying the Application Health

You can check the application's health endpoints:

```bash
# Check the health endpoint
curl http://birthday.local/actuator/health

# For more detailed health information
curl http://birthday.local/actuator/health/readiness
curl http://birthday.local/actuator/health/liveness
```

## Debugging Connection Issues

If you're having trouble connecting to the application, try these troubleshooting steps:

1. Verify that the pods are running:
   ```bash
   kubectl get pods -n birthday
   ```

2. Check pod logs for errors:
   ```bash
   kubectl logs -n birthday deployment/birthday-api
   ```

3. Check Istio gateway status:
   ```bash
   kubectl get gateway -n birthday
   kubectl get virtualservice -n birthday
   ```

4. Make sure the Istio ingress gateway is properly configured and has an external IP:
   ```bash
   kubectl get svc -n istio-system
   ```

5. For local testing on minikube, you may need to use port-forwarding instead:
   ```bash
   kubectl port-forward -n birthday svc/birthday-api 8080:8080
   ```
   Then access the application at http://localhost:8080
