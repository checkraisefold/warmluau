local chef = require("@util/syntax/chef")

export type Chef<State = unknown> = chef.Chef<State>
export type Extensions = chef.Extensions

return {} :: typeof(chef)
