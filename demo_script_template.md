# **Demo Script : Amazon S3**

Points of contact:

**Objective**: Highlight the performance characteristics of Arm-based infrastructure versus x64-based infrastructure, demonstrating that open-source datastores like PostgreSQL and Redis run without issues on Arm, and showcasing the ease of architecture selection for workload placement.

**Duration:** 5-10 minutes

**Audience:** 

**Prerequisites for the Presenter:**

* Google Cloud Project set up  
* Ownership permissions on the Google Cloud Project  
* Follow the instructions in section 1 to pre-run the resource and time intensive performance test, leaving just the UI testing to be performed live.

The following is all setup with the included shell commands:

* gcloud CLI configured  
* kubectl CLI configured  
* GKE Autopilot cluster to easily showcase node selection  
* The provided code files available  
* multi-arch image pre-built via Cloud Build to save time during the demo

**Demo code: [https://github.com/GoogleCloudPlatform/cloud-solutions](https://github.com/GoogleCloudPlatform/cloud-solutions)**  
**Demo instructions: [Java and Web Stacks on Axion](https://googlecloudplatform.github.io/cloud-solutions/arm-reference-guides/web-demo/)**

Note: the paths mentioned in this document are relative to the projects/arm-reference-guides/web-demo directory.

---

### **Introduction (1 minute)**

"Hello again. In our previous demo, we saw how to build and deploy multi-architecture applications. Now, let's dive into the performance aspect. A common question is: 'How does Arm-based infrastructure compare to x64 for real-world workloads, especially with common open-source components?'"

"Today, we'll highlight the performance of our Arm-based environment against its x64 counterpart, focusing on core datastores like PostgreSQL and Redis, and our web application's UI. The goal is to show that Arm not only runs these critical components seamlessly but can also offer compelling performance benefits."

---

### **Section 1: Pre-Run Datastore & Intensive Web Tests (3 minutes)**

**\#\#\#\#**

This set of tests should be performed before the demo, so that the results are stored and can be shown during the presentation.  This is due to the length of time required to complete them.  This will take approximately 10-15 minutes to go through.

Each performance test is defined in a Kubernetes TestRun manifest file. To execute a test, simply apply the desired manifest to your cluster.

* Example: PostgreSQL Read Test on Arm  
  * The test uses the k6 script postgres-reads.js.  
  * The manifest arm-k6-postgres-reads.yaml targets the Arm architecture using a nodeSelector for cloud.google.com/machine-family: c4a.  
  * Run the test with the following command:  
    Bash

```shell
kubectl apply -f web-demo/load-testing/autopilot/arm-k6-postgres-reads.yaml
```

  *   
* Running Other Tests  
  * To run the same test on x64, apply the corresponding manifest: x64-k6-postgres-reads.yaml.  
  * This process is identical for all other datastore and web tests.   
  * Apply the rest of the manifests one at a time, waiting for each k6 job to complete before applying the next :

```shell

kubectl apply -f web-demo/load-testing/autopilot/arm-k6-postgres-writes.yaml
kubectl apply -f web-demo/load-testing/autopilot/arm-k6-redis-reads.yaml
kubectl apply -f web-demo/load-testing/autopilot/arm-k6-all-books-ui.yaml
kubectl apply -f web-demo/load-testing/autopilot/arm-k6-create-review-ui.yaml
kubectl apply -f web-demo/load-testing/autopilot/x64-k6-postgres-reads.yaml
kubectl apply -f web-demo/load-testing/autopilot/x64-k6-postgres-writes.yaml
kubectl apply -f web-demo/load-testing/autopilot/x64-k6-redis-reads.yaml
kubectl apply -f web-demo/load-testing/autopilot/x64-k6-all-books-ui.yaml
kubectl apply -f web-demo/load-testing/autopilot/x64-k6-create-review-ui.yaml
```

**\#\#\#\#**

"To provide comprehensive insights, we've executed a suite of performance tests on both our Arm and x64 clusters *ahead of time* for more intensive workloads. These tests focus on key operations for our datastores and backend services using k6, a powerful load testing tool."

"For **PostgreSQL**, we've run dedicated read and write tests. The k6 scripts postgres-reads.js \[refer to web-demo/load-testing/postgres-reads.js\] and postgres-writes.js \[refer to web-demo/load-testing/postgres-writes.js\] interact directly with the database."

"The Kubernetes TestRun manifests for these, like arm-k6-postgres-reads.yaml \[refer to web-demo/load-testing/autopilot/arm-k6-postgres-reads.yaml\] and x64-k6-postgres-reads.yaml \[refer to web-demo/load-testing/autopilot/x64-k6-postgres-reads.yaml\], show how we targeted specific architectures using nodeSelector (e.g., cloud.google.com/machine-family: c4a for Arm and e2 for x64) and ensured the k6 runner image (${K6\_CONTAINER\_IMAGE\_URL}) was multi-arch compatible \[refer to web-demo/load-testing/Dockerfile\]."

"Similarly, for **Redis**, we've run redis-reads.js \[refer to web-demo/load-testing/redis-reads.js\] and redis-writes.js \[refer to web-demo/load-testing/redis-writes.js\] tests, deployed via manifests like arm-k6-redis-reads.yaml \[refer to web-demo/load-testing/autopilot/arm-k6-redis-reads.yaml\] and x64-k6-redis-writes.yaml \[refer to web-demo/load-testing/autopilot/x64-k6-redis-writes.yaml\]. The arm-redis-helm-values.yaml \[refer to web-demo/k8s-manifests/autopilot/arm-redis-helm-values.yaml\] and x64-redis-helm-values.yaml \[refer to web-demo/k8s-manifests/autopilot/x64-redis-helm-values.yaml\] files configure the Redis deployments on their respective architectures."

"We also pre-ran intensive web tests such as creating reviews (create-review-ui.js \[refer to web-demo/load-testing/create-review-ui.js\]), fetching all books (all-books-ui.js \[refer to web-demo/load-testing/all-books-ui.js\]), and popular books (popular-books-ui.js \[refer to web-demo/load-testing/popular-books-ui.js\]). The results from these pre-run tests, demonstrating metrics like requests per second, latency percentiles, and error rates, are available in Cloud Logging, and we can show those reports or filtered log views now."

---

### **Section 2: Live Web Frontend Test (3 minutes)**

"While the datastore and intensive API tests provide foundational performance data, let's run a lighter web frontend test *live* to demonstrate the process and how easy it is to observe the results."

"We'll use the frontend-ui.js k6 script \[refer to web-demo/load-testing/frontend-ui.js\], which simply hits the root / page of our UI service. This mimics typical user traffic and measures the overall responsiveness."

"We'll initiate the load test for both the Arm UI (arm-k6-frontend-ui.yaml \[refer to web-demo/load-testing/autopilot/arm-k6-frontend-ui.yaml\]) and the x64 UI (x64-k6-frontend-ui.yaml \[refer to web-demo/load-testing/autopilot/x64-k6-frontend-ui.yaml\])."

"As these tests run, all the performance metrics – like HTTP request duration, failed request rates, and custom metrics (e.g., home\_page\_duration) – are automatically streamed to Cloud Logging. By applying the appropriate filters in Cloud Logging, perhaps by k8s\_container.name: k6-runner and then filtering for resource.labels.pod\_name or resource.labels.namespace associated with our Arm or x64 k6 test runs, we can observe the results in near real-time and compare the performance characteristics side-by-side."

---

### **Conclusion (1 minute)**

"What this series of tests demonstrates is multi-fold. First, open-source datastores like PostgreSQL and Redis operate flawlessly on Arm-based infrastructure, offering the same reliability you expect on x64."

"Second, by easily selecting the target architecture in our Kubernetes manifests, we can strategically place our workloads to take advantage of different machine types, which can lead to significant cost savings or performance gains depending on your workload's needs."

"Finally, you've seen how comprehensive load testing can be integrated into your deployment workflow, with results readily accessible in Cloud Logging for continuous monitoring and performance analysis, enabling data-driven decisions on architecture selection. It's truly a seamless experience to manage and optimize your application across diverse CPU architectures on GKE."

"Thank you."

