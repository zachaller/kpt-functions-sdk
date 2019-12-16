# kpt Functions User Guide

## Required Dependencies

- npm
- docker

## Required Kubernetes Feature

For the type generation to work, you need this
[beta feature](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.15.md#customresourcedefinition-openapi-publishing).

If using GKE, this feature is available using an alpha cluster:

```console
gcloud container clusters create $USER-1-14-alpha --enable-kubernetes-alpha --cluster-version=latest --region=us-central1-a --project <PROJECT>
gcloud container clusters get-credentials $USER-1-14-alpha --zone us-central1-a --project <PROJECT>
```

## Developing kpt functions

`create-kpt-functions` is the CLI for generating and interacting with NPM packages containing kpt functions. The CLI
takes care of all the scaffolding, so the user can focus on developing the business-logic.

### Create a NPM package

To start a new NPM package, run the following and follow the instructions and prompts:

```console
mkdir my-package
cd my-package
npm init kpt-functions
```

**Note:** Going forward, all the commands are assumed to be run from `my-package` directory.

This will create the following files:

- `package.json` that declares `kpt-functions` as the only `dependencies` . Everything required to compile, lint and test a kpt function is declared as a `devDependencies` .
- Typescript classes for core and any custom resources generated using the OpenAPI spec published by the chosen cluster.
- Stub for the first function and the corresponding test file.

Run the following command to install all the dependencies and build the generated code:

```console
npm install
```

### Coding

You can now start developing the function using your favorite IDE, e.g.:

```console
code .
```

You can follow [these example functions][1] to understand how to use `kpt-functions` framework library.

Each function has a [Configs][2] parameter represents a document store for Kubernetes objects populated from/to configuration files. It enables performing rich query and mutation operations.

A function can also declare additional input parameters it requires. The framework will automatically
create corresponding CLI flags and pass the values as parameters.

To build the package:

```console
npm run build
```

To build in interactive mode:

```console
npm run watch
```

To run the tests:

```console
npm test
```

### Running a kpt function during development

You can run a kpt function on an existing directory of YAML configs.

The general form is:

```console
npm run local -- [function_name] --source_dir=[source_dir] --sink_dir=[sink_dir] [PARAMS]
```

where parameters are of the form:

```console
--param1=value1 --param2=value2
```

Sample usage below. The '--' before arguments passed to the script are required.

```console
npm run local -- validate_rolebinding --source_dir=path/to/configs/dir/ --sink_dir=output-dir/ --subject_name=alice@foo-corp.com
```

You can choose to overwrite source YAML files by passing `--overwrite`.

```console
npm run local -- validate_rolebinding --source_dir=path/to/configs/dir/ --overwrite --subject_name=alice@foo-corp.com
```

If `--sink_dir` is defined, overwrites YAML files in `--sink_dir`.
If `--sink_dir` is not defined, overwrites YAML files in `--source_dir`.

If enabled, recursively looks for all YAML files in the directory to overwrite.

1. If would write KubernetesObjects to a file that does not exist, creates the file.
2. If would modify the contents of a file, modifies the file.
3. If would not modify the contents of a YAML file, does nothing.
4. If would write no KubernetesObjects to a file, deletes the YAML file if it exists.

### Adding a new kpt function

To add a new kpt functions to an existing package, run:

```console
npm run add-function
```

### Regenerating client types

If want to regenerate classes for core and CRD types that exist on one of your clusters:

```console
npm run update-generated-types
```

### Publishing kpt functions

To build and push docker images for all the functions in the package:

```console
npm run publish-functions
```

This uses the `docker_repo_base` from `package.json` file and configured during initialization. The default value for docker image tag is `dev`. This can be overriden using`--tag` flag:

```console
npm run publish-functions -- --tag=demo
```

## Running kpt functions

### Using `docker run`

After `publish-functions` completes, you can now run the function using `docker run`:

```console
docker run gcr.io/kpt-functions/validate-rolebinding:demo --help
```

Functions can be piped to form sophisticated pipelines:

```console
git clone git@github.com:frankfarzan/foo-corp-configs.git

docker pull gcr.io/kpt-functions/source-yaml-dir:demo
docker pull gcr.io/kpt-functions/recommend-psp:demo
docker pull gcr.io/kpt-functions/hydrate-anthos-team:demo
docker pull gcr.io/kpt-functions/validate-rolebinding:demo
docker pull gcr.io/kpt-functions/sink-yaml-dir:demo

docker run -i -u $(id -u) -v $(pwd)/foo-corp-configs:/source  gcr.io/kpt-functions/source-yaml-dir:demo --input /dev/null --source_dir /source |
docker run -i gcr.io/kpt-functions/recommend-psp:demo |
docker run -i gcr.io/kpt-functions/hydrate-anthos-team:demo |
docker run -i gcr.io/kpt-functions/validate-rolebinding:demo --subject_name alice@foo-corp.com |
docker run -i -u $(id -u) -v $(pwd)/foo-corp-configs:/sink gcr.io/kpt-functions/sink-yaml-dir:demo --sink_dir /sink --output /dev/null --overwrite true
```

Let's walk through each step:

1. Clone the `foo-corp-configs` repo containing example configs.
1. Pull all the docker images.
1. `source-yaml-dir` function recursively **reads** all YAML files from `foo-corp-configs` directory on the host.
   It outputs the content of the directory in a standard format to `stdout`. By default, docker containers
   runs as a non-privileged user. You need to specify `-u` with your user id to access host files as shown above.
1. `recommend-psp` function reads the output of `source-yaml-dir` from `stdin`. This function **mutates** any `PodSecurityPolicy` resources by setting a field called `allowPrivilegeEscalation` to `false`.
1. `hydrate-anthos-team` function similarly operates on the result of the previous function. It looks
   for Kubernetes custom resource of kind `Team`, and based on that **generates** new resources (e.g. `Namespaces` and `RoleBindings`).
1. `validate-rolebinding` function **enforces** a policy that disallows any `RoleBindings` with `subject`
   set to `alice@foo-corp.com`. This steps fails with a non-zero exit code if this policy is violated.
1. `sink-yaml-dir` **writes** the result of the pipeline back to `foo-corp-configs` directory on the host.

Let's see what changes were made to the repo:

```console
cd foo-corp-configs
git status
```

You should see these changes:

1. `podsecuritypolicy_psp.yaml` should have been mutated by `recommend-psp` function.
1. `payments-dev` and `payments-prod` directories created by `hydrate-anthos-team` function.

### Using Workflow Orchestrators

`publish-functions` also generates corresponding custom resources for running your functions using different workflow orchestrators. Currently, the following are supported:

- [Argo Workflow](https://github.com/argoproj/argo/blob/master/examples/README.md)
- [Tekton Task](https://github.com/tektoncd/pipeline/tree/master/docs/README.md)

[1]: todo/path/demo-functions/src/
[2]: ../ts/kpt-functions/src/types.ts