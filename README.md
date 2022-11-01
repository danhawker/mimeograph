## Mimeograph

Noun: A duplicating machine which produces copies from a stencil.

Mimeograph is a simple script to help enable the copying of container artefacts from one source container registry (such as quay.io) to another target container registry. Under the covers, it leverages [oc-mirror](https://github.com/openshift/oc-mirror) to mirror various container artefacts from the source container repository to a file archive (tarball).

The original target use of Mimeograph is to help manage and smooth the process of copying container images into truly air-gapped environments. The original script, written almost 5yrs ago, leveraged Skopeo, but the current script uses `oc-mirror` which in addition to basic container operations, can also manage mirroring Kubernetes Operators and Helm Charts.

`oc-mirror` consumes a configuration file, which contains an `ImageSetConfiguration` which defines the artefacts to be mirrored. This provides a simple, extensible method of manageing the lifecycle of various container images, operators and charts.

Mimeograph builds on `oc-mirror` by helping to automate the end-to-end mirror process, allowing both the scheduled upload of archive files to an S3 bucket, and then the download and import of archived files from S3 to an internal container registry.

### Operation

Mimeograph has two modes of operation, `bundle` and `populate`, which can be configured by simply setting the `operation` field/key in the `mimeograph-config.yaml` file. 
Bundle is used to download, archive and copy to S3 any container artefacts defined.
Populate is the reverse and is used to copy from S3, extract and upload any container artefacts to the target disconnected registry.
 
### Configuration

Configuration for Mimeograph is held within the `mimeograph-config.yaml` file. This is fairly compact and should be mostly self explanatory.

```yaml
apiVersion: mimeograph.io/v1alpha1
kind: MimeographConfiguration
operation: bundle                               # can be bundle or populate
mirror:
  imagesetConfig: /mimeograph/mimeograph-imageset.yaml       # path to the defined ImageSetConfiguration file
  targetRegistryURI: onprem.registry.example.com/mimeograph  # URI of the Target Registry (on-prem)
s3:
  bucket:
    name: mimeograph-bucket                     # Name of the S3 bucket used to upload to/download from 
    endpoint: https://s3-endpoint.example.com/  # Optional S3 endpoint
    subDir: redhat-operators                    # Optional Sub Directory within the bucket
artefacts:
  bundleDir: /mimeograph/bundle                 # Location where oc-mirror will bundle the tarfiles
  metadataDir: /mimeograph/metadata             # Location where oc-mirror will manage image metadata
```

`oc-mirror` uses an additional config file, which defines the ImageSetConfiguration. By default Mimeograph consumes a file called `mimeograph-imageset.yaml` which provides this. 

Full documentation of the ImageSetConfiguration file, can be found in the [`oc-mirror` Github](https://github.com/openshift/oc-mirror).

#### S3 Config

It is generally recommended to use an IAM role to enable access to your S3 bucket. The following policy can be used to limit the needed permissions for that role. Replace `<mimeograph-bucket-name>` with your bucket name.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:ListBucketMultipartUploads",
                "s3:PutBucketCORS"
            ],
            "Resource": "arn:aws:s3:::<mimeograph-bucket-name>"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListMultipartUploadParts",
                "s3:AbortMultipartUpload"
            ],
            "Resource": "arn:aws:s3:::<mimeograph-bucket-name>/*"
        }
    ]
}
```

### Usage

#### Kubernetes/OpenShift
A series of sample kustomize manifests are provided which enable the scheduled use of mimeograph with a CronJob within Kubernetes. See [kubernetes](../kubernetes/README.md) for details.


#### Command Line
As mimeograph is a simple BASH script, you can simply clone this repo and run it directly from the terminal.
Edit the default `mimeograph-config.yaml` config file to suit your needs. 

```
$ ./mimeograph.sh
```

NOTE: If using the command-line, ensure you have `yq`, `oc-mirror` and `awscli` installed and in your $PATH.

#### Podman/Docker
A Containerfile is supplied for running using Podman/Docker. It builds on the lightweight ubi8-minimal image, and  bundles all needed dependencies.

Run the image, remember to mount in the various config files and set env vars for S3
```
$ podman run -d -it --rm --name mimeograph -v ./pull-secret.json:/root/.docker/config.json:Z -v ./mimeograph-config.yaml:/mimeograph/mimeograph-config.yaml:Z -v ./mimeograph-imageset.yaml:/mimeograph/imageset-config.yaml:Z -e AWS_ACCESS_KEY_ID=AAABBBBCCCCDDDDEEEEEFFFFGGGG -e AWS_SECRET_ACCESS_KEY='aabbccddeeffgghhqwertyusdfghjcvbn' localhost/mimeograph
```

### Building the Container Image

```
$ podman build -t mimeograph -f Containerfile .
```

### Limitations

Am sure there are loads, but OTTOMH.

* I wrote it.
* I've done little testing of edge-cases and catching simple typos. To be honest, I've done very little testing at all. Works for my use case.
* `oc-mirror` is great, but the amount of metadata and the inconsistency of channel names & versions across operators/images/charts, makes managing larger collections of operators/channels hard work. Multiple, smaller but discrete mimeograph jobs helps here.


### TODO

* Extend to mirror other artefacts (eg Git archives)
* Investigate using ACK to create the Bucket for AWS in k8s (https://github.com/aws-controllers-k8s/community)
* Port to Python/Go
* Operator style controller & CRD for k8s/OCP
