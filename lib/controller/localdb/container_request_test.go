// Copyright (C) The Arvados Authors. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0

package localdb

import (
	"context"

	"git.arvados.org/arvados.git/lib/config"
	"git.arvados.org/arvados.git/lib/controller/rpc"
	"git.arvados.org/arvados.git/sdk/go/arvados"
	"git.arvados.org/arvados.git/sdk/go/arvadostest"
	"git.arvados.org/arvados.git/sdk/go/auth"
	"git.arvados.org/arvados.git/sdk/go/ctxlog"
	check "gopkg.in/check.v1"
)

var _ = check.Suite(&ContainerRequestSuite{})

type ContainerRequestSuite struct {
	cluster  *arvados.Cluster
	localdb  *Conn
	railsSpy *arvadostest.Proxy
}

func (s *ContainerRequestSuite) TearDownSuite(c *check.C) {
	// Undo any changes/additions to the user database so they
	// don't affect subsequent tests.
	arvadostest.ResetEnv()
	c.Check(arvados.NewClientFromEnv().RequestAndDecode(nil, "POST", "database/reset", nil, nil), check.IsNil)
}

func (s *ContainerRequestSuite) SetUpTest(c *check.C) {
	cfg, err := config.NewLoader(nil, ctxlog.TestLogger(c)).Load()
	c.Assert(err, check.IsNil)
	s.cluster, err = cfg.GetCluster("")
	c.Assert(err, check.IsNil)
	s.localdb = NewConn(s.cluster)
	s.railsSpy = arvadostest.NewProxy(c, s.cluster.Services.RailsAPI)
	*s.localdb.railsProxy = *rpc.NewConn(s.cluster.ClusterID, s.railsSpy.URL, true, rpc.PassthroughTokenProvider)
}

func (s *ContainerRequestSuite) TearDownTest(c *check.C) {
	s.railsSpy.Close()
}

func (s *ContainerRequestSuite) setUpVocabulary(c *check.C, testVocabulary string) {
	if testVocabulary == "" {
		testVocabulary = `{
			"strict_tags": false,
			"tags": {
				"IDTAGIMPORTANCES": {
					"strict": true,
					"labels": [{"label": "Importance"}, {"label": "Priority"}],
					"values": {
						"IDVALIMPORTANCES1": { "labels": [{"label": "Critical"}, {"label": "Urgent"}, {"label": "High"}] },
						"IDVALIMPORTANCES2": { "labels": [{"label": "Normal"}, {"label": "Moderate"}] },
						"IDVALIMPORTANCES3": { "labels": [{"label": "Low"}] }
					}
				}
			}
		}`
	}
	voc, err := arvados.NewVocabulary([]byte(testVocabulary), []string{})
	c.Assert(err, check.IsNil)
	c.Assert(voc.Validate(), check.IsNil)
	s.localdb.vocabularyCache = voc
	s.cluster.API.VocabularyPath = "foo"
}

func (s *ContainerRequestSuite) TestCRCreateWithProperties(c *check.C) {
	s.setUpVocabulary(c, "")
	ctx := auth.NewContext(context.Background(), &auth.Credentials{Tokens: []string{arvadostest.ActiveTokenV2}})

	tests := []struct {
		name    string
		props   map[string]interface{}
		success bool
	}{
		{"Invalid prop key", map[string]interface{}{"Priority": "IDVALIMPORTANCES1"}, false},
		{"Invalid prop value", map[string]interface{}{"IDTAGIMPORTANCES": "high"}, false},
		{"Valid prop key & value", map[string]interface{}{"IDTAGIMPORTANCES": "IDVALIMPORTANCES1"}, true},
		{"Empty properties", map[string]interface{}{}, true},
	}
	for _, tt := range tests {
		c.Log(c.TestName()+" ", tt.name)

		cnt, err := s.localdb.ContainerRequestCreate(ctx, arvados.CreateOptions{
			Select: []string{"uuid", "properties"},
			Attrs: map[string]interface{}{
				"command":         []string{"echo", "foo"},
				"container_image": "arvados/apitestfixture:latest",
				"cwd":             "/tmp",
				"environment":     map[string]string{},
				"mounts": map[string]interface{}{
					"/out": map[string]interface{}{
						"kind":     "tmp",
						"capacity": 1000000,
					},
				},
				"output_path": "/out",
				"runtime_constraints": map[string]interface{}{
					"vcpus": 1,
					"ram":   2,
				},
				"properties": tt.props,
			}})
		if tt.success {
			c.Assert(err, check.IsNil)
			c.Assert(cnt.Properties, check.DeepEquals, tt.props)
		} else {
			c.Assert(err, check.NotNil)
		}
	}
}

func (s *ContainerRequestSuite) TestCRUpdateWithProperties(c *check.C) {
	s.setUpVocabulary(c, "")
	ctx := auth.NewContext(context.Background(), &auth.Credentials{Tokens: []string{arvadostest.ActiveTokenV2}})

	tests := []struct {
		name    string
		props   map[string]interface{}
		success bool
	}{
		{"Invalid prop key", map[string]interface{}{"Priority": "IDVALIMPORTANCES1"}, false},
		{"Invalid prop value", map[string]interface{}{"IDTAGIMPORTANCES": "high"}, false},
		{"Valid prop key & value", map[string]interface{}{"IDTAGIMPORTANCES": "IDVALIMPORTANCES1"}, true},
		{"Empty properties", map[string]interface{}{}, true},
	}
	for _, tt := range tests {
		c.Log(c.TestName()+" ", tt.name)
		cnt, err := s.localdb.ContainerRequestCreate(ctx, arvados.CreateOptions{
			Attrs: map[string]interface{}{
				"command":         []string{"echo", "foo"},
				"container_image": "arvados/apitestfixture:latest",
				"cwd":             "/tmp",
				"environment":     map[string]string{},
				"mounts": map[string]interface{}{
					"/out": map[string]interface{}{
						"kind":     "tmp",
						"capacity": 1000000,
					},
				},
				"output_path": "/out",
				"runtime_constraints": map[string]interface{}{
					"vcpus": 1,
					"ram":   2,
				},
			},
		})
		c.Assert(err, check.IsNil)
		cnt, err = s.localdb.ContainerRequestUpdate(ctx, arvados.UpdateOptions{
			UUID:   cnt.UUID,
			Select: []string{"uuid", "properties"},
			Attrs: map[string]interface{}{
				"properties": tt.props,
			}})
		if tt.success {
			c.Assert(err, check.IsNil)
			c.Assert(cnt.Properties, check.DeepEquals, tt.props)
		} else {
			c.Assert(err, check.NotNil)
		}
	}
}
