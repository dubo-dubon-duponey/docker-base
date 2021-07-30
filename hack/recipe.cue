package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
	"strings"
)

cakes: {
  downloader: scullery.#Cake & {
		recipe: {
			input: dockerfile: "Dockerfile.downloader"

			process: {
		    target: "downloader"
		    platforms: []
			}
			output: {
				directory: "./context"
			}
		}
  }

  overlay: scullery.#Cake & {
		recipe: {
			input: {
				dockerfile: "Dockerfile.runtime"
			}
			process: {
	 			target: "overlay"
		    platforms: []
			}
			output: {
		    directory: "./context/cache"
			}
		}
  }

  builder: scullery.#Cake & {
		recipe: {
			input: {
				dockerfile: "Dockerfile.builder"
			}
			process: {
		    target: "builder"
				platforms: types.#Platforms | * [
					types.#Platforms.#AMD64,
					types.#Platforms.#ARM64,
				]
			}

			output: {
				images: {
					registries: {...} | * {
						"ghcr.io": "dubo-dubon-duponey",
					},
					names: [...string] | * ["base"],
					tags: [...string] | * ["builder-latest"]
				}
			}

			metadata: {
				title: "Dubo Builder",
				description: "Base builder image for all DBDBDP images",
			}
		}
  }

  auditor: scullery.#Cake & {
		recipe: {
			input: {
				dockerfile: "Dockerfile.auditor"
			}
			process: {
		    target: "auditor"
				platforms: types.#Platforms | * [
					types.#Platforms.#AMD64,
					types.#Platforms.#ARM64,
				]
			}

			output: {
				images: {
					registries: {...} | * {
						"ghcr.io": "dubo-dubon-duponey",
					},
					names: [...string] | * ["base"],
					tags: [...string] | * ["auditor-latest"]
				}
			}

			metadata: {
				title: "Dubo Auditor",
				description: "Auditor image",
			}
		}
  }

  node: scullery.#Cake & {
		recipe: {
			input: {
				dockerfile: "Dockerfile.builder"
			}
			process: {
		    target: "builder-node"
				platforms: types.#Platforms | * [
					types.#Platforms.#AMD64,
					types.#Platforms.#ARM64,
					types.#Platforms.#V7,
					types.#Platforms.#S390X,
					types.#Platforms.#PPC64LE,
				]
			}

			output: {
				images: {
					registries: {...} | * {
						"ghcr.io": "dubo-dubon-duponey",
					},
					names: [...string] | * ["base"],
					tags: [...string] | * ["node-latest"]
				}
			}

			metadata: {
				title: "Dubo Builder with Node",
				description: "Base builder image, with node on top",
			}
		}
  }

  golang: scullery.#Cake & {
		recipe: {
			input: {
				dockerfile: "Dockerfile.builder"
			}
			process: {
		    target: "builder-golang"
				platforms: types.#Platforms | * [
					types.#Platforms.#AMD64,
					types.#Platforms.#ARM64,
					types.#Platforms.#I386,
					types.#Platforms.#V7,
					types.#Platforms.#V6,
					types.#Platforms.#S390X,
					types.#Platforms.#PPC64LE,
				]
			}

			output: {
				images: {
					registries: {...} | * {
						"ghcr.io": "dubo-dubon-duponey",
					},
					names: [...string] | * ["base"],
					tags: [...string] | * ["golang-latest"]
				}
			}

			metadata: {
				title: "Just golang",
				description: "Base builder image, with just golang",
			}
		}
  }

  runtime: scullery.#Cake & {
		recipe: {
			input: {
				dockerfile: "Dockerfile.runtime"
			}
			process: {
		    target: "runtime"
				platforms: types.#Platforms | * [
					types.#Platforms.#AMD64,
					types.#Platforms.#ARM64,
					types.#Platforms.#I386,
					types.#Platforms.#V7,
					types.#Platforms.#V6,
					types.#Platforms.#S390X,
					types.#Platforms.#PPC64LE,
				]
			}

			output: {
				images: {
					registries: {...} | * {
						"ghcr.io": "dubo-dubon-duponey",
					},
					names: [...string] | * ["base"],
					tags: [...string] | * ["golang-latest"]
				}
			}

			metadata: {
				title: "Dubo Runtime",
				description: "Base runtime image",
			}
		}
  }
}


// Allow hooking-in a UserDefined environment as icing
UserDefined: scullery.#Icing

cakes: {
	overlay: icing: UserDefined
	downloader: icing: UserDefined
	builder: icing: UserDefined
	runtime: icing: UserDefined
	node: icing: UserDefined
	golang: icing: UserDefined
	auditor: icing: UserDefined
}

// Injectors
injectors: {
	suite: =~ "^(?:jessie|stretch|buster|bullseye|sid)$" @tag(suite, type=string)
	date: =~ "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" @tag(date, type=string)
	platforms: string @tag(platforms, type=string)
	registry: string @tag(registry, type=string)
}

cakes: overlay: recipe: {
	input: from: registry: injectors.registry
}

cakes: downloader: recipe: {
	input: from: registry: injectors.registry
}

overrides: {
	input: from: registry: injectors.registry

	if injectors.platforms != _|_ {
		process: platforms: strings.Split(injectors.platforms, ",")
	}

	output: images: registries: {
		"push-registry.local": "dubo-dubon-duponey",
		"ghcr.io": "dubo-dubon-duponey",
		"docker.io": "dubodubonduponey"
	}

	output: images: tags: [injectors.suite + "-" + injectors.date, injectors.suite + "-latest", "latest"]

	metadata: ref_name: injectors.suite + "-" + injectors.date
}

cakes: golang: recipe: overrides
cakes: runtime: recipe: overrides
cakes: builder: recipe: overrides
cakes: node: recipe: overrides
cakes: auditor: recipe: overrides
