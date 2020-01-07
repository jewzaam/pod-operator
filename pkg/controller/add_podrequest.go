package controller

import (
	"github.com/jewzaam/pod-operator/pkg/controller/podrequest"
)

func init() {
	// AddToManagerFuncs is a list of functions to create controllers and add them to a manager.
	AddToManagerFuncs = append(AddToManagerFuncs, podrequest.Add)
}
