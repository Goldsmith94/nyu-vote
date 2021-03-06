root = global ? window
root.Groups = new Meteor.Collection("groups")

class Group extends ReactiveClass(Groups)
  constructor: (fields) ->
    _.extend(@, fields)
    if fields.name && not this.slug
      this.slug = Utilities.generateSlug(fields.name, Groups)
    Group.initialize.call(@)
  
  hasAdmin: (user) ->
    if user.isGlobalAdmin()
      return true
    netId = user.getNetId()
    return _.contains(@admins, netId) || @creator == netId

  # Whether a user is present in a group as a voter
  containsUser: (user) ->
    return _.contains(@netIds, user.getNetId())

  # Finds which groups have a specific user as an admin
  @findWithAdmin = (user) ->
    netId = user.getNetId()
    return @collection.find(
      {
        $or: [
          {admins: netId}, {creator: netId}
        ]
      }
    )

  activeGroup = {
    current: undefined
    dep: new Deps.Dependency
  }
  @setActive = (group) ->
    activeGroup.dep.changed()
    activeGroup.current = group
    return @

  @getActive = () ->
    activeGroup.dep.depend()
    activeGroup.current?.depend()
    return activeGroup.current

  makeActive: () ->
    Group.setActive(@)

Group.setupTransform()
# Registering offline fields
Group.addOfflineFields(["creator"])
# Promote it to the global scope
root.Group = Group

# Registering Hooks
Groups.before.insert((userId, doc) ->
  doc.slug = Utilities.generateSlug(doc.name, Groups)
  if userId
    user = User.fetchOne(userId)
    netId = user.getNetId()
    doc.creator = netId
    if netId not in doc.admins
      doc.admins.push(netId)
  if (Meteor.isServer)
    Log.warn((if userId then user else "server") +
      " is creating group " + JSON.stringify(doc))
  return doc
)
Groups.before.update((userId, doc, fieldNames, modifier, options) ->
  if (Meteor.isServer)
    user = User.fetchOne(userId)
    Log.warn(user + " is making modification " + JSON.stringify(modifier) +
      " on group " + JSON.stringify(doc))
)

Groups.after.update((userId, doc, fieldNames, modifier, options) ->
  if doc.name != @previous.name
    newSlug = Utilities.generateSlug(doc.name, Groups)
    Groups.update(doc._id, {
      $set: {slug: newSlug}
    })
)

Groups.after.remove((userId, doc) ->
  if (Meteor.isServer)
    user = User.fetchOne(userId)
    Log.warn(user + " is deleting group " + JSON.stringify(doc))
)

# They must be on the whitelist to create groups but they can edit groups that
# they are the admin of
Groups.allow(
  insert: (userId, doc) ->
    user = User.fetchOne(userId)
    return user.isWhitelisted()
  update: (userId, doc) ->
    doc.hasAdmin(User.fetchOne(userId))
  remove: (userId, doc) ->
    doc.hasAdmin(User.fetchOne(userId))
)

# The creator of a group is immutable
Groups.deny(
  update: (userId, doc, fieldNames) ->
    return "creator" in fieldNames
)

Meteor.methods(
  addGroup: (name, description, admins, netIds=[]) ->
    if Meteor.isServer and !Meteor.call("isAGroupAdmin")
      throw new Meteor.Error(500,
      "Error: You are not administrator of any group!")
    Groups.insert(
      name: name
      description: description
      creator: Meteor.user().profile.netId
      admins: admins
      netIds: netIds
    )
    return Groups.findOne({name:name})._id
)
