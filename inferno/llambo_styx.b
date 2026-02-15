implement Llambo_styx;

#
# Styx Protocol Wrapper for C Library Access
#
# This module provides a Styx (9P) file server interface to the llambo_c
# C module, enabling distributed access to llama.cpp across Dis VM boundaries.
#
# File hierarchy:
#   /n/llambo/
#       ctl         - Control file for model management
#       clone       - Clone file to create new model instances
#       models/     - Directory of loaded models
#           0/
#               data    - Inference data file (write prompt, read response)
#               info    - Model information (read-only)
#               status  - Model status (read-only)
#           1/
#               ...
#

include "sys.m";
	sys: Sys;
	fprint, print, sprint: import sys;

include "draw.m";

include "styx.m";
	styx: Styx;
	Rmsg, Tmsg: import styx;

include "styxservers.m";
	styxservers: Styxservers;
	Styxserver, Fid, Navigator: import styxservers;
	nametree: Nametree;
	Tree: import nametree;

include "daytime.m";
	daytime: Daytime;

include "string.m";
	str: String;

include "llambo_c.m";
	llambo_c: Llambo_c;

Llambo_styx: module
{
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

# File types
Qroot, Qctl, Qclone, Qmodels, Qmodeldir, Qdata, Qinfo, Qstatus: con iota;

# Maximum models
MAXMODELS: con 32;

# Model state
Model: adt {
	id: int;
	path: string;
	c_model_id: int;  # ID in C module
	active: int;
};

models: array of ref Model;
nextid: int;
tree: ref Tree;
srv: ref Styxserver;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	styx = load Styx Styx->PATH;
	styxservers = load Styxservers Styxservers->PATH;
	nametree = load Nametree Nametree->PATH;
	daytime = load Daytime Daytime->PATH;
	str = load String String->PATH;
	llambo_c = load Llambo_c Llambo_c->PATH;

	styx->init();
	styxservers->init(styxservers);
	nametree->init();

	# Initialize model array
	models = array[MAXMODELS] of ref Model;
	nextid = 0;

	# Create file tree
	tree = nametree->create(Qroot, sys->aread(Sys->DMDIR|8r555, "root", "root"));
	tree.create(Qroot, (Qctl, "ctl", sys->aread(8r666, "root", "root")));
	tree.create(Qroot, (Qclone, "clone", sys->aread(8r444, "root", "root")));
	tree.create(Qroot, (Qmodels, "models", sys->aread(Sys->DMDIR|8r555, "root", "root")));

	# Parse mount point from args
	mntpt := "/n/llambo";
	if (args != nil) {
		args = tl args;
		if (args != nil)
			mntpt = hd args;
	}

	# Create navigation
	nav := Navigator.new(tree);

	# Start server
	(tchan, srv) := Styxserver.new(sys->fildes(0), nav, Qroot);

	print("llambo_styx: Styx file server started at %s\n", mntpt);

	# Main message loop
	for (;;) {
		gm := <-tchan;
		if (gm == nil)
			break;

		pick m := gm {
		Read =>
			handle_read(m);
		Write =>
			handle_write(m);
		* =>
			srv.default(gm);
		}
	}

	print("llambo_styx: server shutdown\n");
}

#
# Handle read operations
#
handle_read(m: ref Styxservers->Rmsg.Read)
{
	f := m.fid.path & 16rFF;
	
	case f {
	Qctl =>
		# Return cluster status
		status := sprint("models: %d/%d active\n", count_active(), MAXMODELS);
		srv.reply(ref Rmsg.Read(m.tag, array of byte status));

	Qclone =>
		# Return next available model ID
		id := allocate_model_id();
		srv.reply(ref Rmsg.Read(m.tag, array of byte sprint("%d\n", id)));

	Qinfo =>
		# Get model info from path
		model_id := get_model_id_from_fid(m.fid);
		if (model_id >= 0 && models[model_id] != nil) {
			info := llambo_c->get_model_info(models[model_id].c_model_id);
			srv.reply(ref Rmsg.Read(m.tag, array of byte info));
		} else {
			srv.reply(ref Rmsg.Error(m.tag, "model not found"));
		}

	Qstatus =>
		# Return model status
		model_id := get_model_id_from_fid(m.fid);
		if (model_id >= 0 && models[model_id] != nil) {
			status := sprint("model_id: %d\npath: %s\nactive: %d\n",
			                 models[model_id].id,
			                 models[model_id].path,
			                 models[model_id].active);
			srv.reply(ref Rmsg.Read(m.tag, array of byte status));
		} else {
			srv.reply(ref Rmsg.Error(m.tag, "model not found"));
		}

	* =>
		srv.default(m);
	}
}

#
# Handle write operations
#
handle_write(m: ref Styxservers->Rmsg.Write)
{
	f := m.fid.path & 16rFF;
	data := string m.data;
	
	case f {
	Qctl =>
		# Control commands: load, free
		handle_ctl_command(m, data);

	Qdata =>
		# Inference request
		model_id := get_model_id_from_fid(m.fid);
		if (model_id >= 0 && models[model_id] != nil) {
			# Parse inference request (format: "prompt|max_tokens|temperature")
			(fields, nfields) := str->tokenize(data, "|");
			if (nfields >= 1) {
				prompt := hd fields;
				max_tokens := 128;
				temperature := 0.8;
				
				if (nfields >= 2)
					max_tokens = int hd tl fields;
				if (nfields >= 3)
					temperature = real hd tl tl fields;

				# Run inference via FFI
				result := llambo_c->infer(models[model_id].c_model_id, 
				                         prompt, max_tokens, temperature);
				
				# Store result in fid data for subsequent read
				m.fid.data = array of byte result;
				srv.reply(ref Rmsg.Write(m.tag, len m.data));
			} else {
				srv.reply(ref Rmsg.Error(m.tag, "invalid inference request"));
			}
		} else {
			srv.reply(ref Rmsg.Error(m.tag, "model not found"));
		}

	* =>
		srv.reply(ref Rmsg.Error(m.tag, "write not supported"));
	}
}

#
# Handle control commands
#
handle_ctl_command(m: ref Styxservers->Rmsg.Write, cmd: string)
{
	(fields, nfields) := str->tokenize(cmd, " \t\n");
	
	if (nfields < 1) {
		srv.reply(ref Rmsg.Error(m.tag, "empty command"));
		return;
	}

	op := hd fields;
	
	case op {
	"load" =>
		# Load model: load <path> [use_mmap] [n_gpu_layers]
		if (nfields < 2) {
			srv.reply(ref Rmsg.Error(m.tag, "usage: load <path> [use_mmap] [n_gpu_layers]"));
			return;
		}

		path := hd tl fields;
		use_mmap := 1;
		n_gpu := 0;

		if (nfields >= 3)
			use_mmap = int hd tl tl fields;
		if (nfields >= 4)
			n_gpu = int hd tl tl tl fields;

		# Allocate model ID
		model_id := allocate_model_id();
		if (model_id < 0) {
			srv.reply(ref Rmsg.Error(m.tag, "too many models"));
			return;
		}

		# Load via FFI
		c_model_id := llambo_c->load_model(path, use_mmap, n_gpu);
		if (c_model_id < 0) {
			srv.reply(ref Rmsg.Error(m.tag, "failed to load model"));
			return;
		}

		# Create model entry
		model := ref Model;
		model.id = model_id;
		model.path = path;
		model.c_model_id = c_model_id;
		model.active = 1;
		models[model_id] = model;

		# Create model directory in tree
		qid := (Qmodeldir + model_id) << 8;
		tree.create(Qmodels, (qid, sprint("%d", model_id), 
		            sys->aread(Sys->DMDIR|8r555, "root", "root")));
		tree.create(qid, (qid | Qdata, "data", sys->aread(8r666, "root", "root")));
		tree.create(qid, (qid | Qinfo, "info", sys->aread(8r444, "root", "root")));
		tree.create(qid, (qid | Qstatus, "status", sys->aread(8r444, "root", "root")));

		srv.reply(ref Rmsg.Write(m.tag, len array of byte cmd));

	"free" =>
		# Free model: free <model_id>
		if (nfields < 2) {
			srv.reply(ref Rmsg.Error(m.tag, "usage: free <model_id>"));
			return;
		}

		model_id := int hd tl fields;
		if (model_id < 0 || model_id >= MAXMODELS || models[model_id] == nil) {
			srv.reply(ref Rmsg.Error(m.tag, "invalid model_id"));
			return;
		}

		# Free via FFI
		llambo_c->free_model(models[model_id].c_model_id);
		models[model_id] = nil;

		srv.reply(ref Rmsg.Write(m.tag, len array of byte cmd));

	* =>
		srv.reply(ref Rmsg.Error(m.tag, sprint("unknown command: %s", op)));
	}
}

#
# Helper functions
#

allocate_model_id(): int
{
	for (i := 0; i < MAXMODELS; i++) {
		if (models[i] == nil)
			return i;
	}
	return -1;
}

count_active(): int
{
	count := 0;
	for (i := 0; i < MAXMODELS; i++) {
		if (models[i] != nil && models[i].active)
			count++;
	}
	return count;
}

get_model_id_from_fid(fid: ref Fid): int
{
	# Extract model ID from fid path
	# Path format: (Qmodeldir + model_id) << 8 | file_type
	qid := (fid.path >> 8) & 16rFF;
	if (qid >= Qmodeldir && qid < Qmodeldir + MAXMODELS)
		return qid - Qmodeldir;
	return -1;
}
