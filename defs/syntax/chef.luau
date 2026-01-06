local chef = require("@util/syntax/chef")

export type Chef<State = unknown> = chef.Identity<State>
export type Extensions = chef.Extensions

return {} :: typeof(chef)
