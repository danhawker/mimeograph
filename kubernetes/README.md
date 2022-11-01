## Using Mimeograph with Kubernetes/OpenShift

Mimeograph was originally designed to help automate `oc-mirror` to make mirroring into air-gapped OpenShift environments easier to manage. `oc-mirror` already helps with this enormously, but further automation is needed to make this both more manageable and easier to keep track of upgrades of the many moving parts involved.

Once setup, Mimeograph runs as a simple k8s CronJob. Depending on configuration, this can be used to schedule a regular 'sync' of defined ImageSet(s), bundling new and updates artefacts.

### Super Simple and Contrived Example

![Mimeograph on Kubernetes](https://github.com/danhawker/mimeograph/assets/mimeograph-k8s.png  "Mimeograph on Kubernetes")

1) Mimeograph 'bundle' job mirrors artefacts from upstream repositories
2) Mimeograph pushes bundled archive files to S3 bucket storage
3) Archive files securely transfered across the divide using some _magical technology_...
4) ...and is pushed to an on-prem S3 bucket
5) Mimeograph pulls archive files from S3 storage
6) Mimeograph 'populate' job, uploads mirrored artefacts to on-prem Container Registry

### Kustomize Manifests
A series of Kustomise manifests are provided, these...

#### Baseline
The initial baseline creates any core resources.

* Create a namespace (mimeograph)
* Create a ServiceAccount (mimeograph) and RoleBinding
* Creates 2x PVCs to use as persistent storage to store the Artefacts `oc-mirror` mirrors and the metadata it creates
* Creates a CronJob which runs twice a day.


#### AWS-S3 Overlay
There is an example Kustomization overlay for when using Mimeograph to send to an AWS provided S3 bucket. The Kustomization...

* Creates a ConfigMap for the Mimeograph config file - `mimeograph-config.yaml`
* Creates a ConfigMap for the `oc-mirror` ImageSetConfiguration file - `mimeograph-imageset.yaml`
* Creates a ConfigMap that contains the credentials required to access upstream and downstream registries - `config.json`
* Patches PVCs to correct StorageClass
* OPTIONALLY Creates a Secret to contain the S3 credentials for accessing the S3 Bucket

A Secret containing the correct credentials needs to be created within the namespace to allow access to the S3 bucket.

#### ODF-S3 Overlay
OpenShift Data Foundation provides an `ObjectBucketClaim` resource which acts similarly to a traditional Kubernetes PersistentVolumeClaim, but can provision on-demand S3 compatible Object Buckets in ODF. The Kustomization...

* Creates a ConfigMap for the Mimeograph config file - `mimeograph-config.yaml`
* Creates a ConfigMap for the `oc-mirror` ImageSetConfiguration file - `mimeograph-imageset.yaml`
* Creates a ConfigMap that contains the credentials required to access upstream and downstream registries - `config.json`
* Patches PVCs to correct StorageClass

When using an OBC, there is no need to create a Secret to contain the S3 credentials. A Secret which contains these credentials is automatically created by the ODF Operator upon creation, which Mimeograph can consume. 

### Usage

* Ensure you have sufficient privileges within k8s/OpenShift to create all the needed resources
* Adjust an existing overlay as a starter or copy and use as a template. 
* Adjust all config files, credentials, etc to suit the environment.
* Create resources using the `oc` CLI.

```
$ oc apply -k overlays/aws-s3
```

If you wish to kick-off an ad-hoc job to test...

```
$ oc create job --from cronjob/mimeograph -n mimeograph manual-bundle-01
```
