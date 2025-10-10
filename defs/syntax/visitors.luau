local visitors = require("@util/syntax/visitors")

export type Base<State = unknown> = visitors.Base<State>
export type AddType = visitors.AddType
export type AddScope = visitors.AddScope
export type Create<State = unknown> = visitors.Create<State>

return {} :: typeof(visitors)
