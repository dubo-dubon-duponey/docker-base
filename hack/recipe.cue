package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
	"strings"
)

// XXX WIP: clearly the injector is defective at this point and has to be rethought
// It's probably a better approach to hook it into the recipe, or the env to avoid massive re-use problems

// Entry point if there are environmental definitions
UserDefined: scullery.#Icing & {
	// XXX add injectors here?
//				cache: injector._cache_to
//				cache: injector._cache_from
}

// XXX unfortunately, you cannot have tags in imported packages, so this has to be hard-copied here

defaults: {
	tags: [
		types.#Image & {
			registry: "push-registry.local"
 			image: "dubo-dubon-duponey/base"
			// tag: cakes.debian.recipe.process.args.TARGET_SUITE + "-" + cakes.debian.recipe.process.args.TARGET_DATE
		},
		types.#Image & {
			registry: "push-registry.local"
			image: "dubo-dubon-duponey/base"
			tag: "latest"
		},
		types.#Image & {
   		registry: "ghcr.io"
   		image: "dubo-dubon-duponey/base"
   		// tag: cakes.debian.recipe.process.args.TARGET_SUITE + "-" + cakes.debian.recipe.process.args.TARGET_DATE
   	},
		types.#Image & {
			registry: "ghcr.io"
			image: "dubo-dubon-duponey/base"
			tag: "latest"
		}
	],
	platforms: [
		types.#Platforms.#AMD64,
		types.#Platforms.#I386,
		types.#Platforms.#V7,
		types.#Platforms.#V6,
		types.#Platforms.#S390X,
		types.#Platforms.#ARM64,
		// qemue / bullseye busted
		types.#Platforms.#PPC64LE,
	]

	suite: "bullseye"
	date: "2021-07-01"
	tarball: "\(suite)-\(date).tar"
}

injector: {
	_i_tags: * strings.Join([for _v in defaults.tags {_v.toString}], ",") | string @tag(tags, type=string)

	_tags: [for _k, _v in strings.Split(_i_tags, ",") {
		types.#Image & {#fromString: _v}
	}]
	// _tags: [...types.#Image]
	//if _i_tags != "" {
	//}
	//_tags: [for _k, _v in strings.Split(_i_tags, ",") {
	//	types.#Image & {#fromString: _v}
	//}]

	_i_platforms: * strings.Join(defaults.platforms, ",") | string @tag(platforms, type=string)

	_platforms: [...string]

	if _i_platforms == "" {
		_platforms: []
	}
	if _i_platforms != "" {
		_platforms: [for _k, _v in strings.Split(_i_platforms, ",") {_v}]
	}

	_target_suite: * defaults.suite | =~ "^(?:buster|bullseye|sid)$" @tag(target_suite, type=string)
	_target_date: * defaults.date | =~ "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" @tag(target_date, type=string)

	_directory: * "context/debian/cache" | string @tag(directory, type=string)

	_from_image_runtime: types.#Image & {#fromString: *"ghcr.io/dubo-dubon-duponey/debian:bullseye-2021-07-01@sha256:d17b322f1920dd310d30913dd492cbbd6b800b62598f5b6a12d12684aad82296" | string @tag(from_image_runtime, type=string)}
	_from_image_builder: types.#Image & {#fromString: *"ghcr.io/dubo-dubon-duponey/debian:bullseye-2021-07-01@sha256:d17b322f1920dd310d30913dd492cbbd6b800b62598f5b6a12d12684aad82296" | string @tag(from_image_builder, type=string)}
	_from_tarball: *defaults.tarball | string @tag(from_tarball, type=string)
}

			// XXX this is really environment instead righty?
			// This to specify if a offband repo is available
			//TARGET_REPOSITORY: #Secret & {
			//	content: "https://apt-cache.local/archive/debian/" + strings.Replace(args.TARGET_DATE, "-", "", -1)
			//}

cakes: {
  downloader: scullery.#Cake & {
		recipe: {
			input: {
				root: "./"
				context: "./context"
				from: builder: injector._from_image_builder
		    dockerfile: "Dockerfile.downloader"
			}
			process: {
		    target: "downloader"
		    platforms: []
			}
			output: {
				directory: "./context"
			}
		}

		icing: UserDefined
  }

  overlay: scullery.#Cake & {
		recipe: {
			// XXX could be smarter in alternating from image and from tarball
			input: {
				root: "./"
				context: "./context"
				from: builder: injector._from_image_builder
				dockerfile: "Dockerfile.runtime"
			}
			process: {
	 			target: "overlay"
		    platforms: []
			}
			output: {
		    directory: "context/cache"
			}
		}

		icing: UserDefined
  }

  builder: scullery.#Cake & {
		recipe: {
			// XXX could be smarter in alternating from image and from tarball
			input: {
				root: "./"
				context: "./context"
				from: runtime: injector._from_image_runtime
				dockerfile: "Dockerfile.builder"
			}
			process: {
		    target: "builder"
				platforms: injector._platforms
			}

			output: {
				tags: injector._tags
			}

			// Standard metadata for the image
			metadata: {
				// ref_name: process.args.TARGET_SUITE + "-" + process.args.TARGET_DATE,
				title: "Dubo Builder",
				description: "Base builder image for all DBDBDP images",
			}
		}
		icing: UserDefined
  }

  auditor: scullery.#Cake & {
		recipe: {
			// XXX could be smarter in alternating from image and from tarball
			input: {
				root: "./"
				context: "./context"
				from: runtime: injector._from_image_runtime
				dockerfile: "Dockerfile.auditor"
			}
			process: {
		    target: "auditor"
				platforms: injector._platforms
			}

			output: {
				tags: injector._tags
			}

			// Standard metadata for the image
			metadata: {
				// ref_name: process.args.TARGET_SUITE + "-" + process.args.TARGET_DATE,
				title: "Dubo Auditor",
				description: "Auditor image",
			}
		}
		icing: UserDefined
  }

  node: scullery.#Cake & {
		recipe: {
			// XXX could be smarter in alternating from image and from tarball
			input: {
				root: "./"
				context: "./context"
				from: runtime: injector._from_image_runtime
				dockerfile: "Dockerfile.builder"
			}
			process: {
		    target: "builder-node"
				platforms: injector._platforms
			}
			output: {
				tags: injector._tags
			}
			metadata: {
				// ref_name: process.args.TARGET_SUITE + "-" + process.args.TARGET_DATE,
				title: "Dubo Builder with Node",
				description: "Base builder image, with node on top",
			}
		}
		icing: UserDefined
  }

  runtime: scullery.#Cake & {
		recipe: {
			// XXX could be smarter in alternating from image and from tarball
			input: {
				root: "./"
				context: "./context"
				from: runtime: injector._from_image_runtime
				dockerfile: "Dockerfile.runtime"
			}
			process: {
		    target: "runtime"
				platforms: injector._platforms
			}
			output: {
				tags: injector._tags
			}
			metadata: {
				// ref_name: process.args.TARGET_SUITE + "-" + process.args.TARGET_DATE,
				title: "Dubo Runtime",
				description: "Base runtime image",
			}
		}
		icing: UserDefined
  }
}
