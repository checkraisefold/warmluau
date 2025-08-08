export type Nav = { string }
export type ValidPath = Nav | string

export type Api = {
	to_nav: (path: ValidPath) -> Nav,
	from_str: (path: string) -> Nav,
	clone_nav: (path: ValidPath) -> Nav,
	to_str: (path: ValidPath) -> string,
	from_nav: (path: Nav) -> string,
	has_root: (path: ValidPath) -> boolean,
	absolute_eh: (path: ValidPath) -> boolean,
	parent: (path: ValidPath) -> string,
	starts_with: (path: ValidPath, base: ValidPath) -> boolean,
	stops_with: (path: ValidPath, child: ValidPath) -> boolean,
	normalize: (path: ValidPath) -> string?,
	real_parent: (path: ValidPath) -> string?,
	equal: (first: ValidPath?, second: ValidPath?) -> boolean,
	last: (path: ValidPath) -> string?,
	stem: (path: ValidPath) -> string?,
	extension: (path: ValidPath) -> string?,
	set_extension: (path: ValidPath, to: string?) -> string,
	push: (path: ValidPath, onto: ValidPath) -> Nav,

	SEPARATOR: string,
}

return nil
