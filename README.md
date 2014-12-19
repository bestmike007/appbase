[![Build Status](https://travis-ci.org/bestmike007/appbase.svg?branch=master)](https://travis-ci.org/bestmike007/appbase)

Nowadays BaaS and mBaaS platforms (e.g. [firebase](https://www.firebase.com/), [parse](https://www.parse.com/), [appbase.io](https://appbase.io/)) abound. Open source solutions (e.g. [usergrid](http://usergrid.incubator.apache.org/) using LAMP, [helios](http://helios.io/) using Ruby, [deployd](http://deployd.com/) and [StrongLoop](http://strongloop.com/) using nodejs, and a lot more) are also available. And appbase is much less than those.

What is appbase? Appbase is a lightweight backend based on rails for rubyists with the following basic features:

+ User registration and authentication
+ REST model crud api
+ Expose business logic with a simple line of code
+ 3rd party authentication
+ Push notifications
+ Payment integration
+ Other basic features mostly required by apps

Appbase is/does not:

+ Use GUI to configure models and/or business logic
+ Use configuration files

Appbase is under development; and will be kept as simple as possible.

## Basic Usage

Configure in `application.rb`:

``` ruby
  # enable appbase
  config.appbase.enabled = true
  # default: '/appbase'
  # config.appbase.mount = "/_api"
  config.appbase.user_identity = :User # required
  config.appbase.token_store = :cookies # :cookies, :headers, :params
  config.appbase.token_key_user = :u
  config.appbase.token_key_session = :s
  config.appbase.models.push :User, :Role, :Permission, :UserProfile, :TodoItem, :GroupTodoList
```

Implement `UserIdentityModel#authenticate_by_token(user, token)`:

``` ruby
  class User < ActiveRecord::Base
    def self.authenticate_by_token(user, token)
      # TODO cache the result
      User.find_by(user: user, token: token)
    end
  end
```

Set up CRUD permissions for models:

``` ruby
  class TodoItem < ActiveRecord::Base
  
    # Allow query
    allow_query :mine
    # or
    allow_query :within => :related_to_me
    def self.related_to_me(current_user)
      TodoItem.where user_id: current_user.id
    end
    # or
    allow_query :within do |current_user|
      TodoItem.where user_id: current_user.id
    end
    
    # Allow create/update/delete
    allow_create :mine
    # or
    allow_update :if => :related_to_me?
    def self.related_to_me?(current_user, obj)
      obj.user_id == current_user.id
    end
    # or
    allow_delete :if do |current_user, obj|
      obj.user_id == current_user.id
    end
    
    # restrict_query_columns usage:
    #   restrict_query_columns <only | except>: <single_column | column_list>
    # examples:
    #   restrict_query_columns only: [:user_id, :created_at, :updated_at]
    #   restrict_query_columns only: :updated_at
    #   restrict_query_columns except: [:content]
    restrict_query_columns only: [:updated_at, :created_at]
    
    # restrict_query_operators usage:
    #   restrict_query_operators :column1, :column2, <only | except>: <:equal | :compare | :in>
    # examples:
    #   restrict_query_operators :user_id, :created_at, :updated_at, only: [:equal, :compare]
    #   restrict_query_operators :user_id, :created_at, :updated_at, except: :in
    #   restrict_query_operators :title, only: :equal
    restrict_query_operators :updated_at, :created_at, except: :in
    
  end
```

Expose business logic methods:

``` ruby
  
  # don't have to be an active record
  class GroupTodoList
  
    include AppBase::ModelConcern
    
    expose_to_appbase :list_group_todos, auth: true # default to true
    
    def self.list_group_todos(current_user)
      TodoItem.find_all group_id: current_user.group_id
    end
    
  end
  
  # public methods, e.g. authentication, does not have the `current_user` parameter
  class User < ActiveRecord::Base
    
    expose_to_appbase :authenticate, :external_auth, auth: false
    
    def self.authenticate(user, pass)
      user = User.find_by username: user, password: pass
      return nil if user.nil?
      user.last_login = Time.now
      user.session_token = SecureRandom.hex
      user.save!
      user.session_token
    end
    
    def self.external_auth(user, options={})
      case options[:provider]
      when 'twitter'
        # do authenticate
      when 'facebook'
        # do authenticate
      else
        raise "unsupported provider"
      end
    end
    
  end
```

And that's all. 

## The Request Scheme

Apps (including iOS app, Andriod app, web app with angularjs or similar frontend framework, etc.) are communicating with appbase using HTTP/HTTPS.

### The REST API

Basic CRUD api conforms to the representational state transfer (REST) architectural style. Following sections are using model `Note (id, title, content)` as an example to illustrate how a model is created, updated, deleted, and how to perform a query on a model (Supose that the appbase engine is mount on `/_api`).

#### Create

Request to create a model with JSON serialized body:

```
PUT /_api/note HTTP/1.1
HOST xxx
Content-Type: application/json

{ "title" : "test" , "content" : "hello", "user_id" : 1 }
```

The server response on success:

```
HTTP/1.1 200 OK

{"status":"ok","id":1}
```

On failure:

```
HTTP/1.1 200 OK

{"status":"error","msg":"error_msg"}
```

#### Update

Almost the same as create except for adding the `:id` parameter (e.g. `/_api/note/:id`):

```
PUT /_api/note/1 HTTP/1.1
HOST xxx
Content-Type: application/json

{ "title" : "test" , "content" : "hello appabse!", "user_id" : 1 }
```

#### Delete

```
DELETE /_api/note/1 HTTP/1.1
HOST xxx
```

#### Query

The request:

```
GET /_api/note?p=1&ps=20 HTTP/1.1
HOST xxx
```

In the parameters, `p` indicates the page of the query; `ps` indicates the page size of the query. Except for the pagination parameters, query parameters are allowed to filter the query. Supose we need to perform a query on `Note.id`, here are some examples on how to query:

+ /_api/note?p=1&ps=20`&id=1` Equal to 1
+ /_api/note?p=1&ps=20`&id.lt=10` Less than 10
+ /_api/note?p=1&ps=20`&id.le=10` Less than or equal to 10
+ /_api/note?p=1&ps=20`&id.gt=1` Greater than 1
+ /_api/note?p=1&ps=20`&id.ge=1` Greater than or equal to 1
+ /_api/note?p=1&ps=20`&id.lt=10&id.ge=1` Greater than or equal to 1 and less than 10
+ /_api/note?p=1&ps=20`&id.in=[1,2,3]` In 1, 2, 3
+ /_api/note?p=1&ps=20`&id.nin=[1,2,3]` Not in 1, 2, 3
+ /_api/note?p=1&ps=20`&id.n=true` Is null
+ /_api/note?p=1&ps=20`&id.nn=true` Not null

`OR` conditions are not supported for now, use exposed methods instead.

### RPC Methods

Model methods with custom business logic can be exposed as rpc methods, take the method `Note.related_to_me(current_user, limit)` as example.

```
POST /_api/note/related_to_me HTTP/1.1
HOST xxx

limit=10
```

Response from the backend should be:

```
HTTP/1.1 200 OK

{"status":"ok","data":[{"id":1,"key":"value"},{"id":2,"key":"value"},{"id":3,"key":"value"}]}
```

If the method is defined with an `options` parameter, e.g. `Note.related_to_me(current_user, options={})`, then optional request arguments are passed to the method within the option hash object.

## Known Issues

+ `OR` conditions are not supported for active record query
+ Multiple accessible query base
+ Write more test cases
+ Complete the document

You're welcome to contribute to this project by creating an issue / a pull request.

---

## License

Appbase is released under the [MIT License](http://opensource.org/licenses/MIT).